import asyncio
from bleak import BleakScanner, AdvertisementData
import subprocess
import re
import socket
import logging

# 正则匹配 WiFi SSID 和密码，格式为 ssid;password
wifi_pattern = re.compile(r"^(.*?);(.*)$")

# BLE UUID 设置（需与 Android 保持一致）
WIFI_SERVICE_UUID = "0000fff1-0000-1000-8000-00805f9b34fb"

connected = False
broadcasting = False

def disconnect_wifi(interface="wlan0", forget_ssid=None):
    # 断开当前连接
    subprocess.run(["sudo", "nmcli", "device", "disconnect", interface])
    print(f"已断开接口 {interface} 的连接")

    # 如果提供了 ssid，则删除该配置（防止自动重连）
    if forget_ssid:
        subprocess.run(["sudo", "nmcli", "connection", "delete", forget_ssid])
        print(f"已删除连接配置：{forget_ssid}")

# 尝试连接 WiFi
def connect_wifi(ssid, password):
    global connected
    if connected:
        return

    print(f"尝试连接 WiFi：SSID={ssid}, 密码={password}")
    try:
        # 先执行 WiFi 扫描（解决 nmcli 可能找不到新热点问题）
        subprocess.run(["sudo", "iwlist", "wlan0", "scan"], stdout=subprocess.DEVNULL)

        result = subprocess.run(
            ["sudo", "nmcli", "device", "wifi", "connect", ssid, "password", password],
            capture_output=True, text=True
        )
        print("连接输出：", result.stdout or result.stderr)
        if "成功" in result.stdout or "successfully" in result.stdout.lower():
            connected = True
    except Exception as e:
        print("连接 WiFi 失败：", e)

# 获取本地 IP 地址
def get_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "0.0.0.0"
    finally:
        s.close()

# BLE 广播树莓派 IP
async def broadcast_ip():
    global broadcasting
    broadcasting = True
    subprocess.call(["sudo", "hciconfig", "hci0", "up"])  # 打开蓝牙适配器
    while broadcasting:

        ip = get_ip()
        if ip == "0.0.0.0":
            print("错误：未获取到有效 IP")
            continue

        # 将 IP 转换为 4 字节数组（关键修正）
        ip_octets = list(map(int, ip.split('.')))  # 例如 192.168.1.100 → [192, 168, 1, 100]
        ip_bytes = bytes(ip_octets)

        # 构建 BLE 广播数据（完整格式）
        adv_data = [
            "0x08", "0x0008",        # HCI 命令头
            "0x11",                  # 总数据长度: 17 bytes (0x11)
            "0x02", "0x01", "0x06",  # Flags: LE General Discoverable
            "0x08",                  # Manufacturer Data 长度: 8 bytes
            "0xFF",                  # Manufacturer Data 类型
            "0x34", "0x12"           # 制造商 ID (小端序 0x1234)
        ] + [f"0x{b:02X}" for b in ip_bytes]  # 添加 IP 字节
        # 使用 hcitool + hcitoolcmd 广播（部分系统需 sudo）

        # 发送广播
        subprocess.call(["sudo", "hcitool", "-i", "hci0", "cmd"] + adv_data)

        subprocess.call(["sudo", "hciconfig", "hci0", "leadv", "3"])  # 设置 LE 广播

        print(f"已广播 IP：{ip}")
        await asyncio.sleep(1)

# 解析 BLE 广播数据
def parse_wifi_data(data: bytes):
    try:
        text = data.decode("utf-8", errors="ignore")
        match = wifi_pattern.match(text)
        if match:
            ssid = match.group(1)
            password = match.group(2)
            return ssid, password
    except Exception as e:
        print("解析广播数据失败：", e)
    return None, None

def is_wifi_connected():
    result = subprocess.run(["nmcli", "-t", "-f", "DEVICE,STATE", "device"], capture_output=True, text=True)
    for line in result.stdout.strip().split("\n"):
        if "wlan0:connected" in line:
            return True
    return False


# BLE 广播监听回调
def detection_callback(device, advertisement_data: AdvertisementData):
    global connected
    if connected:
        return

    wifi_data = advertisement_data.service_data.get(WIFI_SERVICE_UUID)
    if wifi_data:
        print(f"[{device.address}] 收到广播数据：{wifi_data}")
        ssid, password = parse_wifi_data(wifi_data)
        if ssid and password:
            ssid = "AndroidShare_" + ssid  # 根据你的 Android 热点命名规则
            if password == "disconnect":
                disconnect_wifi(forget_ssid=ssid)
            else:
                connect_wifi(ssid, password)

# 主流程
async def main():
    global connected,broadcasting
    scanner = BleakScanner(detection_callback)
    broadcast_task = None
    
    print("初始化 BLE 广播监听器...")
    await scanner.start()
    print("BLE 广播监听已启动")
    
    while True:
        if not is_wifi_connected():
            if broadcast_task:
                print("WiFi 断开，停止广播任务")
                broadcasting = False
                broadcast_task.cancel()
                try:
                    await broadcast_task
                except asyncio.CancelledError:
                    pass
                broadcast_task = None
            connected = False
            print("WiFi 已连接，停止扫描")
        else:
            if not broadcasting and broadcast_task is None:
                print("开始广播 IP 地址")
                broadcast_task = asyncio.create_task(broadcast_ip())
        await asyncio.sleep(1)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("手动停止脚本。")