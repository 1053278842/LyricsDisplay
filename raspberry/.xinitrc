#!/bin/bash
export DISPLAY=:0

# 取消屏保、DPMS、省电模式
xset s off
xset -dpms
xset s noblank

# 背景黑
# xsetroot -solid black

xrandr --output default --mode 240x320

# 隐藏鼠标（1秒后自动隐藏）
# unclutter -idle 0.1 -root &

# 等待 X 环境稳定一点（可选）
sleep 2

# 最后启动浏览器
chromium-browser \
  --window-size=240,640 \
  --disable-features=Translate,TranslateUI \
  --fast --fast-start \
  --disable-popup-blocking \
  --disable-infobars \
  --start-fullscreen \
  --incognito \
  --disable-session-crashed-bubble \
  --allow-running-insecure-content \
  --kiosk file:///home/pi/index.html \
  --force-device-scale-factor=0.1 \
  --no-sandbox \
  --disable-sync-translation \
  --hide-cursor \
  --override-language-preference=zh-CN \
  --window-position=0,0