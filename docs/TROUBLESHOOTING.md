# 排查手册

按现象查。每一条都是这套系统上真实踩过的坑。

---

## 一、屏幕相关

### 屏幕全黑，但树莓派是开着的

先分清三种黑：

| 情况 | 判断方法 | 说明 |
| --- | --- | --- |
| **空闲黑屏** | 放首歌就出字 | 正常。网页只有收到歌词/暂停状态才渲染，否则就是纯黑 |
| **fsck 黑屏** | 刚掉电过，SSH 还能进 | 正常。`fsck.repair=yes` 在修根分区，5~10 分钟，别断电 |
| **真没起来** | SSH 也进不去，或 `systemctl status kiosk` 不是 active | 见下面「X / kiosk 没起来」 |

### 屏幕上出现桌面壁纸

LightDM 桌面会话和 kiosk 都画在同一个 `/dev/fb1` 上，谁后画谁覆盖。

```bash
sudo systemctl disable --now lightdm
sudo systemctl restart kiosk
```

### 屏幕上有个鼠标箭头

X 服务器层的光标，不是网页里的。检查：

```bash
cat /etc/X11/xinit/xserverrc   # 应该有 -nocursor
ps -ef | grep '[X]org'         # 应该带 -nocursor
```

没有的话重跑 `sudo ./install.sh`。

### 屏幕有内容但方向/镜像不对

棱镜是反射，需要镜像补偿：

```bash
sudo /home/pi/mirror.sh off   # 正常
sudo /home/pi/mirror.sh h     # 左右翻（最常见）
sudo /home/pi/mirror.sh v     # 上下翻
sudo /home/pi/mirror.sh hv    # 180°
```

### 屏幕花屏 / 撕裂 / 有雪花

- SPI 线太长或杜邦线接触不良 → 把 `config.txt` 里的 `speed=60000000` 降到 `32000000`
- 电源不够 → 用 5V/3A 官方电源，别用手机充电头带

### 没有 `/dev/fb1`

说明 fbtft overlay 没加载：

```bash
dmesg | grep -i fbtft          # 应该有 fb_st7789v ... frame buffer
grep -n 'fbtft' /boot/firmware/config.txt
```

`config.txt` 里必须有完整的一行 `dtoverlay=fbtft,spi0-0,st7789v,...`，且 `dtparam=spi=on` 没有被注释。改完必须 `sudo reboot`。

---

## 二、kiosk / X 没起来

```bash
systemctl status kiosk --no-pager -l
journalctl -u kiosk -b --no-pager | tail -40
```

常见原因：

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `Cannot establish any listening sockets` | 上次的 X 没退干净 | `sudo pkill -9 Xorg; sudo rm -f /tmp/.X0-lock; sudo systemctl restart kiosk` |
| kiosk 反复重启 | Chromium 崩了 | 看 `/home/pi/.xsession-errors` |
| 起来后立刻退出 | `index.html` 路径不对 | `.xinitrc` 里是 `file:///home/pi/index.html`，确认文件在 |

---

## 三、手机端「外设链接」一直是红的

这个灯的含义：**手机有没有收到树莓派通过 BLE 广播的 IP**。

按顺序查：

### 1. 树莓派这边有没有在广播

```bash
systemctl status lyrichud-ble --no-pager
journalctl -u lyrichud-ble -b --no-pager | tail -20
```

正常应该看到：

```
wlan0 已连接：你的WiFi（192.168.x.x）
BLE 广播已启动：IP=192.168.x.x（company id 0x1234）
```

如果看到 `wlan0 没有 IP`：树莓派没联网，先解决网络。
如果服务根本没启动：`sudo systemctl restart lyrichud-ble`。

### 2. 蓝牙适配器在不在

```bash
bluetoothctl show          # 应该显示 Powered: yes
rfkill list                # 不能是 Soft blocked: yes
```

### 3. 手机能不能扫到

装个 **nRF Connect**，扫描，找一台带 `0x1234` 制造商数据的设备。

- 找不到 → 树莓派广播没发出去
- 找得到但 App 还是红 → 手机权限：**定位服务必须打开**，且 App 要有「附近的设备」权限

### 4. 为什么原来的 ble.py 不行

老版本用 `hcitool`/`hciconfig` 手工拼 HCI 包：

- 长度字段算错（声明 17 字节，实际 11 字节）→ 控制器直接丢弃
- Bookworm 的 BlueZ 5.66 已经删掉 `hcitool` → 命令根本不存在
- 异常被吞掉，`broadcasting` 变量还是 True → 永远不会重启

现在这版改用 `bluetoothctl` 的 advertise 子菜单发 manufacturer data，长度由 BlueZ 计算。

---

## 四、手机热点打不开

**可以完全不管。**

原设计是「手机开热点 → 树莓派连热点 → 树莓派广播自己的 IP」，但很多 ROM（尤其 MIUI/HyperOS）会限制 App 创建 LocalOnlyHotspot。

只要**手机和树莓派连同一个 WiFi**，整条链路照样通：树莓派广播的是 `wlan0` 的局域网 IP，手机直接访问即可。

App 里的「热点状态」红了不影响使用。

---

## 五、网络相关

### 树莓派和手机不在一个网段

两台设备必须能互相 ping 通。检查树莓派 IP：

```bash
hostname -I
```

手机浏览器打开 `http://<树莓派IP>:5588/`：

- 返回 404 → 通了（Flask 没有 `/` 路由，404 就是活着）
- 打不开 → 检查手机 VPN（Clash 之类可能把局域网流量也劫走）

### 手机开 VPN 后歌词停了

Clash 等 VPN 如果开了全局模式，可能把发往 `192.168.x.x` 的请求也送进隧道。
把 `192.168.0.0/16` 加到「直连 / Bypass」列表即可。

---

## 六、安装过程相关

### `apt-get update` 卡很久

国内直连 `raspbian.raspberrypi.com` 常常只有几 KB/s。

```bash
sudo ./install.sh --cn-mirror
```

或者手动换源后重跑。

### `/boot/firmware` 是只读的

掉电或 IO 错误后内核会把 vfat 挂成 `ro`（`errors=remount-ro`）。安装脚本会尝试自动 `remount,rw`，如果还不行：

```bash
BOOTDEV=$(findmnt -no SOURCE /boot/firmware)
sudo fsck.vfat -a "$BOOTDEV"
sudo mount -o remount,rw /boot/firmware
```

### 读卡器中途掉线，卡里出现一堆 `BCBCBCBC.BCB`

这是 Windows 读卡器接触不良导致的**假象**，不一定是真损坏：

1. 换一个 USB 口（优先主板后面的）
2. 用「安全删除硬件」弹出
3. `chkdsk X: /f` 复查

### 首次开机黑屏很久

第一次开机会跑 `fsck` + 自动安装，**5~10 分钟正常**。日志在卡的 `lyrichud/report.txt`。

---

## 七、日志都在哪

| 内容 | 位置 |
| --- | --- |
| kiosk / X | `journalctl -u kiosk -b` |
| Flask | `journalctl -u flask_app -b` |
| BLE | `journalctl -u lyrichud-ble -b` |
| Chromium 崩溃 | `/home/pi/.xsession-errors` |
| 首启安装 | 卡上 `lyrichud/report.txt` |
| 旧版脚本日志 | `/home/pi/kiosk.log`、`/home/pi/code/*.log` |