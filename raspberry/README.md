# raspberry/ — 树莓派端全部配置

这里放的**不是示例，是真机上正在跑的原始文件**。任何一台新的 Pi 4B + Bookworm，跑一遍 `install.sh` 就能变成现在这台机器。

```
raspberry/
├── install.sh              ← 一键安装（幂等，支持 --dry-run）
├── boot/
│   ├── config.txt          ← 真机 /boot/firmware/config.txt 原件（含 ST7789V 屏参）
│   ├── config.txt.append   ← 安装时真正追加的干净段落（去掉了原文件里那行粘连）
│   ├── cmdline.txt         ← 真机 /boot/firmware/cmdline.txt 原件
│   └── xorg.conf.d/        ← 5 个 X 配置：把 X 钉在 /dev/fb1、240×240、禁熄屏
├── systemd/
│   ├── kiosk.service       ← X11 + Chromium 看门狗
│   ├── flask_app.service   ← 5588 歌词服务
│   └── lyrichud-ble.service← BLE 广播本机 IP（安卓端靠它找到树莓派）
├── home/
│   ├── index.html          ← 歌词页（含 --mirror-x/--mirror-y 镜像变量）
│   ├── js/                 ← socket.io / 歌词解析
│   ├── pixel12.woff2       ← 像素字体
│   ├── kiosk.sh            ← kiosk 循环脚本
│   ├── mirror.sh           ← 一键切镜像方向（h / v / hv / off）
│   ├── xinitrc             ← 装到 /home/pi/.xinitrc
│   └── xserverrc           ← 装到 /etc/X11/xinit/xserverrc（含 -nocursor）
├── code/
│   ├── flask_app.py        ← Flask + Socket.IO，端口 5588
│   ├── ble.py              ← BLE：广播本机 wlan0 IP（company id 0x1234）
│   ├── requirements.txt
│   └── gpio_backlight_demo.py  ← 背光 PWM 小实验（可选，没装进服务）
└── provision/              ← 空白卡首次开机自动安装（见该目录 README）
```

## 快速使用

```bash
git clone https://github.com/1053278842/LyricsDisplay.git
cd LyricsDisplay/raspberry
sudo ./install.sh --dry-run      # 先看会做什么
sudo ./install.sh --write-boot   # 真正安装
sudo reboot
```

完整步骤、接线、排查见：
- [../docs/SETUP.md](../docs/SETUP.md)
- [../docs/HARDWARE.md](../docs/HARDWARE.md)
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)

## 两个容易踩的点

1. **`boot/config.txt` 里那行 `dtoverlay=fbtft,...` 看着像粘连重复，那是能正常工作的原始值，不要"顺手清理"**——改了可能屏幕配色/方向就变了。`install.sh` 追加的是 `config.txt.append` 里已经清洗过的版本。
2. **不要同时用 LightDM 桌面和 kiosk**：两者都画在 `/dev/fb1` 上，会互相覆盖（表现为屏幕上突然出现桌面壁纸）。`install.sh` 默认禁用 lightdm，除非你加 `--keep-desktop`。