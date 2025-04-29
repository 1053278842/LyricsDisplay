#!/bin/bash
#
# kiosk.sh — 启动 X11 + Chromium Kiosk，并在崩溃后自动重启
#

# 要在 SPI 屏上显示，导出 FRAMEBUFFER
export FRAMEBUFFER=/dev/fb1

# 启动 Flask
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 启动 Flask 服务…" >> /home/pi/kiosk.log
# 激活虚拟环境并启动 Flask
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 激活虚拟环境…" >> /home/pi/code/flask_app.log
source /home/pi/code/myenv/bin/activate
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 当前 Python 环境：" >> /home/pi/code/flask_app.log
which python3 >> /home/pi/code/flask_app.log
python3 --version >> /home/pi/code/flask_app.log

python3 /home/pi/code/flask_app.py >> /home/pi/code/flask_app.log 2>&1 &

python3 /home/pi/code/ble.py >> /home/pi/code/ble.log 2>&1 &
FLASK_PID=$!


# 无限循环：只要 X 或 Chromium 退出，就重启
while true; do
  startx
  sleep 5
done

# 如果主循环 somehow 退出了，杀掉 Flask
kill $FLASK_PIDc