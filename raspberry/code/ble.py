#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LyricHud 树莓派侧 BLE 桥接（修复版，可直接替换 raspberry/ble.py）

原版 ble.py 的两条链路里，“树莓派 -> 手机”这一条从来没有真正发出去过：
  - HCI 广播数据的长度字段写错（0x11 / 0x08），控制器会直接丢弃这条命令；
  - 依赖 hcitool / hciconfig，Raspberry Pi OS Bookworm 已经删掉它们；
  - 一旦 subprocess 抛异常，broadcast_ip() 这个 task 就静默死掉，broadcasting 还是 True，
    永远不会重启 —— 表面看 flask 和屏幕都正常，其实一根广播都没有。

本版本改成用 bluetoothctl 的 advertise 子菜单发 manufacturer data（BlueZ 5.50+ 通用），
并且把“手机热点 -> 树莓派”“树莓派 IP -> 手机”两条链路都做了容错和日志。

用法：
    sudo python3 ble.py

依赖：
    sudo apt install -y bluez
    sudo apt install -y python3-bleak        # Bookworm 有；没有就用 sudo pip3 install bleak
"""

import asyncio
import logging
import os
import re
import subprocess
import threading
import time

# ----------------------------------------------------------------------------
# 和安卓端约定的常量（必须和 App 里一致，别乱改）
# ----------------------------------------------------------------------------
COMPANY_ID = 0x1234                                     # BleScanner 里 MANUFACTURER_ID
PHONE_UUID = "0000fff1-0000-1000-8000-00805f9b34fb"     # BleAdvertiser 里 serviceUuid
IFACE = "wlan0"
ADV_NAME = "LyricHud-Pi"

log = logging.getLogger("ble")


# ----------------------------------------------------------------------------
# 系统命令小工具
# ----------------------------------------------------------------------------
def run(cmd, timeout=40):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        log.error("找不到命令：%s", cmd[0])
    except subprocess.TimeoutExpired:
        log.error("命令超时：%s", " ".join(cmd))
    return None


def wlan_ip():
    """只取 wlan0 的 IPv4。

    原版 get_ip() 是 UDP connect 8.8.8.8 反查本机地址，如果树莓派同时插着网线，
    拿到的会是 eth0 的地址，手机热点里根本访问不到。这里强制只看 wlan0。
    """
    r = run(["nmcli", "-g", "IP4.ADDRESS", "device", "show", IFACE], 10)
    if r and r.returncode == 0:
        for line in r.stdout.splitlines():
            line = line.strip()
            if "/" in line:
                return line.split("/")[0]
    r = run(["ip", "-4", "-o", "addr", "show", "dev", IFACE], 10)
    if r:
        m = re.search(r"inet (\d+\.\d+\.\d+\.\d+)", r.stdout)
        if m:
            return m.group(1)
    return None


def wlan_connection():
    """当前 wlan0 连着的连接名，没连就是 None。"""
    r = run(["nmcli", "-g", "GENERAL.CONNECTION", "device", "show", IFACE], 10)
    if r and r.returncode == 0:
        name = r.stdout.strip()
        if name and name != "--":
            return name
    return None


# ----------------------------------------------------------------------------
# 树莓派 -> 手机：把自己的 IP 广播出去
# ----------------------------------------------------------------------------
class Advertiser:
    """用 bluetoothctl 的 advertise 子菜单广播 manufacturer data。

    BlueZ 侧生成的就是 AD 结构 [len][0xFF][0x34 0x12][4 字节 IP]，
    安卓 ScanRecord.getManufacturerSpecificData(0x1234) 拿到的正好是那 4 个字节。
    """

    def __init__(self, company_id=COMPANY_ID):
        self.company_id = company_id
        self.wanted_ip = None
        self.current_ip = None
        self.proc = None
        self.out = []
        threading.Thread(target=self._run, name="adv", daemon=True).start()

    # ---- 外部线程调用
    def set_ip(self, ip):
        self.wanted_ip = ip

    # ---- 内部
    def _pump(self, proc):
        for line in proc.stdout:
            line = line.rstrip()
            if not line:
                continue
            self.out.append(line)
            del self.out[:-120]
            log.debug("[bluetoothctl] %s", line)

    def _cmd(self, line, delay=0.4):
        p = self.proc
        if p is None or p.poll() is not None:
            raise RuntimeError("bluetoothctl 已退出")
        p.stdin.write(line + "\n")
        p.stdin.flush()
        time.sleep(delay)

    def _spawn(self):
        log.info("启动 bluetoothctl ...")
        self.proc = subprocess.Popen(
            ["bluetoothctl"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        threading.Thread(target=self._pump, args=(self.proc,), daemon=True).start()
        self._cmd("power on", 1.5)
        self._cmd("menu advertise", 0.3)
        self._cmd("name {}".format(ADV_NAME), 0.3)
        self._cmd("back", 0.3)

    def _set_data(self, ip):
        octets = [int(x) for x in ip.split(".")]
        if len(octets) != 4:
            raise ValueError("IP 格式不对：%s" % ip)
        body = " ".join("0x{:02x}".format(o) for o in octets)
        # 注意 bluetoothctl 的字节是 strtol(base 0) 解析的，
        # 必须写 0x??，写 "52" 会被当成十进制 52 = 0x34。
        self._cmd("menu advertise", 0.3)
        self._cmd("manufacturer 0x{:04x} {}".format(self.company_id, body), 0.5)
        self._cmd("back", 0.3)

    def _kill(self):
        if self.proc is not None and self.proc.poll() is None:
            try:
                self.proc.terminate()
                self.proc.wait(timeout=3)
            except Exception:
                pass
        self.proc = None

    def _run(self):
        while True:
            try:
                self._spawn()
                ip = self.wanted_ip
                while ip is None:
                    time.sleep(0.5)
                    ip = self.wanted_ip
                self._set_data(ip)
                self._cmd("advertise on", 1.5)
                self.current_ip = ip

                bad = [l for l in self.out[-12:]
                       if ("Invalid" in l) or ("Failed" in l) or ("not available" in l)]
                if bad:
                    log.error("BLE 广播可能没成功，bluetoothctl 说：%s", bad)
                else:
                    log.info("BLE 广播已启动：IP=%s（company id 0x%04x）", ip, self.company_id)

                while True:
                    ip = self.wanted_ip
                    if ip and ip != self.current_ip:
                        self._set_data(ip)
                        self.current_ip = ip
                        log.info("树莓派 IP 变了，广播已更新：%s", ip)
                    if self.proc.poll() is not None:
                        raise RuntimeError("bluetoothctl 进程退出")
                    time.sleep(0.5)
            except Exception as e:
                log.warning("BLE 广播异常：%s；2 秒后重启 bluetoothctl", e)
                self._kill()
                self.current_ip = None
                time.sleep(2)


# ----------------------------------------------------------------------------
# 手机 -> 树莓派：收热点 SSID/密码，然后用 nmcli 连上去
# ----------------------------------------------------------------------------
def join_hotspot(suffix, password):
    ssid = suffix if suffix.startswith("AndroidShare_") else "AndroidShare_" + suffix
    log.info("收到手机热点信息：SSID=%s", ssid)

    if password == "disconnect":
        run(["nmcli", "connection", "down", ssid], 20)
        run(["nmcli", "connection", "delete", ssid], 20)
        log.info("已按要求断开并删除连接 %s", ssid)
        return

    if wlan_connection() == ssid:
        log.info("wlan0 已经连着 %s，跳过", ssid)
        return

    run(["nmcli", "device", "wifi", "rescan"], 20)   # 失败也无所谓
    r = run(["nmcli", "--wait", "30", "device", "wifi", "connect",
             ssid, "password", password], 70)
    if r and r.returncode == 0:
        log.info("已连接 %s", ssid)
    else:
        detail = ((r.stdout or "") + (r.stderr or "")).strip() if r else "nmcli 不可用"
        log.error("连接 %s 失败：%s", ssid, detail)


class RequestBox:
    """扫描线程 -> 主线程 的一次性请求盒。"""

    def __init__(self):
        self._pending = None
        self._lock = threading.Lock()

    def offer(self, suffix, password):
        with self._lock:
            if self._pending == (suffix, password):
                return
            self._pending = (suffix, password)

    def take(self):
        with self._lock:
            item, self._pending = self._pending, None
            return item


def make_callback(box):
    def callback(device, advertisement_data):
        service_data = advertisement_data.service_data or {}
        raw = service_data.get(PHONE_UUID)
        if raw is None:
            for key, value in service_data.items():
                if key.lower().startswith("0000fff1"):
                    raw = value
                    break
        if raw is None:
            return
        try:
            text = bytes(raw).decode("utf-8", "ignore")
        except Exception:
            return
        if ";" not in text:
            return
        suffix, password = text.split(";", 1)
        log.info("收到手机 BLE 广播：%s（来自 %s）", text, device.address)
        box.offer(suffix.strip(), password.strip())

    return callback


async def scan_forever(box):
    callback = make_callback(box)
    while True:
        try:
            from bleak import BleakScanner
        except ImportError:
            log.warning("没装 bleak（sudo apt install python3-bleak）：跳过手机热点扫描，"
                        "但树莓派 IP 广播不受影响，仍可正常工作")
            await asyncio.sleep(60)
            continue
        try:
            scanner = BleakScanner(callback)
            await scanner.start()
            log.info("BLE 扫描已启动，等待手机热点广播 ...")
            while True:
                await asyncio.sleep(5)
        except Exception as e:
            log.warning("BLE 扫描异常：%s；5 秒后重试", e)
            await asyncio.sleep(5)


# ----------------------------------------------------------------------------
def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)-5s %(message)s",
        datefmt="%H:%M:%S",
    )

    if hasattr(os, "geteuid") and os.geteuid() != 0:
        log.warning("建议用 sudo 运行：广播和改网络都需要 root")

    box = RequestBox()
    advertiser = Advertiser()

    threading.Thread(
        target=lambda: asyncio.run(scan_forever(box)),
        name="scan",
        daemon=True,
    ).start()

    last = object()
    while True:
        pending = box.take()
        if pending:
            threading.Thread(target=join_hotspot, args=pending, daemon=True).start()

        ip = wlan_ip()
        conn = wlan_connection()
        snapshot = (ip, conn)
        if snapshot != last:
            last = snapshot
            if ip:
                log.info("wlan0 已连接：%s（%s）", conn or "?", ip)
                advertiser.set_ip(ip)
            else:
                log.warning("wlan0 没有 IP —— 树莓派还没连上手机热点，暂时没有地址可以广播")
        time.sleep(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log.info("手动停止")