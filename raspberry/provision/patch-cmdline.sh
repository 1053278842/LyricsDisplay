#!/bin/sh
# 把一次性启动钩子写进卡的 cmdline.txt（Linux / macOS）
# 用法： ./patch-cmdline.sh /media/$USER/bootfs
set -eu

BOOT="${1:-}"
if [ -z "$BOOT" ]; then
  echo "用法: $0 <bootfs 挂载点>"
  echo "例如: $0 /media/pi/bootfs"
  exit 1
fi
F="$BOOT/cmdline.txt"
[ -f "$F" ] || { echo "找不到 $F"; exit 1; }

cp -a "$F" "$F.bak"
LINE="$(tr -d '\n' < "$F")"
ARGS="systemd.run=/boot/firmware/lyrichud/firstrun.sh systemd.run_success_action=none systemd.run_failure_action=none systemd.unit=kernel-command-line.target"

# 幂等：先剥掉旧参数
LINE="$(printf '%s' "$LINE" | sed 's| systemd\.run=[^ ]*||g; s| systemd\.run_success_action=[^ ]*||g; s| systemd\.run_failure_action=[^ ]*||g; s| systemd\.unit=kernel-command-line\.target||g')"

printf '%s %s\n' "$(printf '%s' "$LINE" | sed 's/ *$//')" "$ARGS" > "$F"
sync
echo "已写入 $F:"
cat "$F"