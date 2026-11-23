#!/bin/bash
# 切换歌词屏的镜像方向，并干净地重启 kiosk
# 用法： sudo /home/pi/mirror.sh h    水平镜像（棱镜左右翻转，默认）
#        sudo /home/pi/mirror.sh v    垂直镜像（上下翻转）
#        sudo /home/pi/mirror.sh hv   上下左右都翻（等于旋转 180°）
#        sudo /home/pi/mirror.sh off  正常显示
set -e
case "$1" in
  h)   X=-1; Y=1;  desc="水平镜像" ;;
  v)   X=1;  Y=-1; desc="垂直镜像" ;;
  hv)  X=-1; Y=-1; desc="上下左右都翻" ;;
  off) X=1;  Y=1;  desc="正常显示" ;;
  *)   echo "用法: sudo $0 h|v|hv|off"; exit 1 ;;
esac

FILE=/home/pi/index.html
sed -i -E "s/--mirror-x: *-?1;/--mirror-x: $X;/; s/--mirror-y: *-?1;/--mirror-y: $Y;/" "$FILE"
echo "已设置：$desc  (--mirror-x: $X  --mirror-y: $Y)"
grep -n -- '--mirror-x' "$FILE" | head -2

# systemd 默认会杀掉整个 cgroup，所以 restart 能干净地重建 X + Chromium
systemctl restart kiosk.service
echo "kiosk 已重启，约 10 秒后出画面"