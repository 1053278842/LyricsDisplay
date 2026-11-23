#!/bin/sh
# =============================================================================
# LyricHud 首次开机自动安装
#
# 由 /boot/firmware/cmdline.txt 里的 systemd.run= 触发，root 身份执行，只跑一次。
# 它做三件事：
#   1) 把 /boot/firmware/lyrichud/raspberry 复制到 /opt（FAT 分区不能直接执行脚本）
#   2) 调用 install.sh --write-boot 完成安装
#   3) 把执行记录写到 /boot/firmware/lyrichud/report.txt，并把钩子从 cmdline 里删掉
#
# 出问题时的排查：把卡插回电脑，看 /boot/firmware/lyrichud/report.txt
# =============================================================================

SRC=/boot/firmware/lyrichud
WORK=/opt/lyrichud-install
REPORT="$SRC/report.txt"

# 让输出同时进日志和串口控制台
exec >>"$REPORT" 2>&1

echo "=================================================="
echo "LyricHud firstrun  $(date -Is)"
echo "=================================================="
echo "cmdline: $(cat /proc/cmdline)"
echo "model:   $(tr -d '\0' < /proc/device-tree/model 2>/dev/null)"
echo "os:      $(head -2 /etc/os-release | tr '\n' ' ')"

if [ ! -d "$SRC/raspberry" ]; then
  echo "!! 找不到 $SRC/raspberry，放弃"
  exit 1
fi

if [ ! -d /home/pi ]; then
  echo "!! /home/pi 不存在：本项目的 systemd 单元按 pi 用户写死，请用用户名 pi 刷系统"
  exit 1
fi

# 1) 复制到 ext4 再执行（FAT 上没有可执行位）
echo "--- 复制安装源到 $WORK ---"
rm -rf "$WORK"
mkdir -p "$WORK"
cp -r "$SRC/raspberry" "$WORK/raspberry"
chmod -R u+rwX "$WORK"
chmod +x "$WORK/raspberry/install.sh" "$WORK/raspberry/provision/firstrun.sh" 2>/dev/null

# 2) 读取 Wi-Fi 配置（可选）
if [ -f "$SRC/lyrichud.conf" ]; then
  echo "--- 读取 $SRC/lyrichud.conf ---"
  cat "$SRC/lyrichud.conf" | sed 's/^WIFI_PSK=.*/WIFI_PSK=***/'
  # shellcheck disable=SC1091
  . "$SRC/lyrichud.conf"
fi
export WIFI_SSID="${WIFI_SSID:-}"
export WIFI_PSK="${WIFI_PSK:-}"

# 3) 安装
echo "--- 执行 install.sh --write-boot ---"
if "$WORK/raspberry/install.sh" --write-boot; then
  RESULT=OK
else
  RESULT=FAILED
fi
echo "--- install.sh 结果：$RESULT ---"

# 4) 自清理：把本次钩子从 cmdline 里删掉，脚本改名，保证只跑一次
NEW=$(sed 's| systemd\.run=[^ ]*||g; s| systemd\.run_success_action=[^ ]*||g; s| systemd\.run_failure_action=[^ ]*||g; s| systemd\.unit=kernel-command-line\.target||g' /boot/firmware/cmdline.txt)
printf '%s\n' "$NEW" > /boot/firmware/cmdline.txt
mv -f "$SRC/firstrun.sh" "$SRC/firstrun.done.sh" 2>/dev/null
sync

echo "--- firstrun 结束 $RESULT $(date -Is) ---"
echo

# 5) 安装成功就自动重启，让新的 config.txt / cmdline.txt 生效
#    重启后再看屏幕；日志留在卡上的 lyrichud/report.txt
if [ "$RESULT" = OK ]; then
  echo "--- 安装成功，5 秒后自动重启 ---"
  sync
  nohup sh -c 'sleep 5; systemctl reboot' >/dev/null 2>&1 &
fi