#!/bin/bash
# LyricHud kiosk 启动脚本
#
# 由 kiosk.service 拉起，只负责两件事：
#   1) 导出 SPI 屏对应的 framebuffer
#   2) 循环运行 startx（X 或 Chromium 崩了就自动重来）
#
# Flask 归 flask_app.service 管，BLE 广播归 lyrichud-ble.service 管，
# 这里不要再启动它们，否则会出现重复进程互相抢端口/抢蓝牙。

export FRAMEBUFFER=/dev/fb1

LOG=/home/pi/kiosk.log
echo "[$(date '+%F %T')] kiosk 启动" >> "$LOG"

while true; do
  startx
  echo "[$(date '+%F %T')] X 退出，5 秒后重启" >> "$LOG"
  sleep 5
done