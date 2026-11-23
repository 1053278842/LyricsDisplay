# 从零点亮：安装指南

两种方式，任选其一：

| 方式 | 适合 | 需要几分钟 |
| --- | --- | --- |
| **A. 空白卡一键**（推荐） | 新卡、没有键盘显示器、想一次搞定 | 刷机 5 分钟 + 开机自动装 5 分钟 |
| **B. 手动安装** | 已经有能跑的系统、想自己控制每一步 | 10 分钟 |

两条路装出来的结果完全一样。

---

## 方式 A：空白卡一键

详细步骤见 [raspberry/provision/README.md](../raspberry/provision/README.md)。要点：

1. Imager 刷 **Bookworm 64-bit**，用户名必须是 **pi**，勾选 SSH
2. 把 `raspberry/` 整个目录 + `firstrun.sh` 复制到 `bootfs:\lyrichud\`
3. 需要自动连 Wi-Fi 就补一个 `lyrichud.conf`
4. 运行 `patch-cmdline.bat I:` 打钩子
5. 插卡开机，等 5 分钟，它会自己装完并重启一次

---

## 方式 B：手动安装

### 0. 前提

- Raspberry Pi 4B + Raspberry Pi OS **Bookworm 64-bit**
- 用户名 **pi**（systemd 单元里写死了 `/home/pi`）
- 树莓派**能上网**（要装 apt 包和 Python 依赖）
- 屏幕按 [HARDWARE.md](HARDWARE.md) 接好

### 1. 先把 SPI 屏点亮

```bash
sudo ./install.sh --write-boot
```

这会往 `/boot/firmware/config.txt` 追加屏幕配置、改 `cmdline.txt`，然后：

```bash
sudo reboot
```

重启后应该能看到 `/dev/fb1`：

```bash
$ cat /sys/class/graphics/fb1/name
fb_st7789v
```

> 没有 `fb1` 说明 overlay 没生效。检查 `/boot/firmware/config.txt` 末尾有没有
> `# ===== LyricHud SPI display =====` 段，以及 `dtoverlay=fbtft` 那行是否完整。

### 2. 装软件

```bash
git clone https://github.com/1053278842/LyricsDisplay.git
cd LyricsDisplay/raspberry
sudo ./install.sh              # 已经写过 boot 配置的话，不用再加 --write-boot
```

脚本做的事（幂等，可重复执行）：

| 步骤 | 内容 |
| --- | --- |
| 1 | `apt install` Chromium、Xorg、fbdev 驱动、bluez、python3-venv… |
| 2 | 部署 `index.html`、`js/`、字体、`kiosk.sh`、`mirror.sh`、`.xinitrc` 到 `/home/pi` |
| 3 | 部署 `flask_app.py`、`ble.py` 到 `/home/pi/code` |
| 4 | 建 venv 并装 Flask / Socket.IO / bleak |
| 5 | 写入 5 个 `xorg.conf.d` 配置 + `xserverrc`（`-nocursor`） |
| 6 | 安装并启用 3 个 systemd 单元 |
| 7 | 禁用 LightDM（避免和 kiosk 抢同一块 framebuffer） |
| 8 | （仅 `--write-boot`）写屏幕配置 |

常用参数：

```bash
sudo ./install.sh --dry-run        # 只看会做什么
sudo ./install.sh --keep-desktop   # 保留桌面（可能抢屏）
WIFI_SSID=你家WiFi WIFI_PSK=密码 sudo -E ./install.sh   # 顺手配网
```

### 3. 验证

```bash
systemctl is-active kiosk flask_app lyrichud-ble    # 三个都应是 active
ss -lntp | grep 5588                                # Flask 在监听
hostname -I                                         # 记下 IP
```

屏幕上应该出现绿框歌词页（没放歌时是暂停图标）。

### 4. 手机端

装 [lyrics_hud_android](https://github.com/1053278842/lyrics_hud_android) 的 APK，授予通知使用权/定位/蓝牙权限，点「运行」。
「外设链接」变绿就说明树莓派通过 BLE 把 IP 告诉手机了。

---

## 装完之后

### 镜像方向（棱镜必须）

```bash
sudo /home/pi/mirror.sh h      # 左右翻（默认）
sudo /home/pi/mirror.sh v      # 上下翻
sudo /home/pi/mirror.sh hv     # 180°
sudo /home/pi/mirror.sh off    # 正常
```

### 看日志

```bash
journalctl -u kiosk -f            # 浏览器 / X
journalctl -u flask_app -f        # 歌词服务
journalctl -u lyrichud-ble -f     # BLE 广播
```

### 改 Wi-Fi

```bash
sudo nmcli device wifi connect "WiFi名" password "密码"
```

改完 IP 会变，但 `lyrichud-ble.service` 每秒钟广播一次当前 IP，手机端会自动跟上，不用重新配对。

### 升级

```bash
cd LyricsDisplay && git pull
cd raspberry && sudo ./install.sh
```

---

## 更新记录：这次装好的机器和原版的差异

| 项 | 值 |
| --- | --- |
| X 分辨率 | 240×240（`99-spi-screen.conf` 里 `Virtual 240 240`） |
| framebuffer | `/dev/fb1`，RGB565 |
| 鼠标 | 已在 X 服务器层禁用（`-nocursor`） |
| 桌面会话 | 已禁用（`systemctl disable lightdm`） |
| 开机自启 | `kiosk.service` / `flask_app.service` / `lyrichud-ble.service` |