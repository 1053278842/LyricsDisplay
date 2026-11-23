#!/bin/bash
# =============================================================================
# LyricHud 树莓派一键安装脚本
#
#   适用：Raspberry Pi 4B + Raspberry Pi OS Bookworm 64-bit
#   作用：把「SPI 小屏 + Chromium kiosk + Flask + BLE 广播」整套环境装好
#
#   常用：
#     sudo ./install.sh --write-boot        首次在新卡上安装（会改 /boot/firmware）
#     sudo ./install.sh                     已经改过 boot 配置时，只装用户态
#     sudo ./install.sh --dry-run           只打印将要做什么，不实际改动
#     sudo ./install.sh --clean-wifi-profiles   清掉历史遗留的 AndroidShare_* 热点配置
#     sudo ./install.sh --keep-desktop      保留 LightDM 桌面（默认会禁用它，防止抢屏）
#     sudo ./install.sh --cn-mirror         把 apt 源换成 USTC 镜像（国内提速）
#
#   顺手配 Wi-Fi：
#     WIFI_SSID=你的WiFi WIFI_PSK=密码 sudo -E ./install.sh --write-boot
#
#   重复执行是安全的（幂等）。
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_USER="${LYRICHUD_USER:-pi}"
PI_HOME="/home/$PI_USER"
CODE_DIR="$PI_HOME/code"
VENV="$CODE_DIR/myenv"
BOOT=/boot/firmware

DRY_RUN=0
WRITE_BOOT=0
CLEAN_WIFI=0
CN_MIRROR=0
KEEP_DESKTOP=0
WIFI_SSID="${WIFI_SSID:-}"
WIFI_PSK="${WIFI_PSK:-}"

C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_OFF=$'\033[0m'
log()  { printf '%s[LyricHud]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s[警告]%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
die()  { printf '%s[错误]%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

run() {   # 需要 root 的命令统一走这里，dry-run 时只打印
  if [ "$DRY_RUN" = 1 ]; then printf '    + %s\n' "$*"; else "$@"; fi
}

cpf() {   # cpf <源> <目标> <权限>
  local src="$1" dst="$2" mode="${3:-0644}"
  if [ "$DRY_RUN" = 1 ]; then printf '    + install %s -> %s (%s)\n' "$src" "$dst" "$mode"
  else install -m "$mode" "$src" "$dst"; fi
}

backup() {
  local f="$1"
  [ -e "$f" ] || return 0
  if [ "$DRY_RUN" = 1 ]; then printf '    + backup %s\n' "$f"
  else cp -a "$f" "$f.bak.$(date +%Y%m%d-%H%M%S)"; fi
}

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

for arg in "$@"; do
  case "$arg" in
    --dry-run)              DRY_RUN=1 ;;
    --write-boot)           WRITE_BOOT=1 ;;
    --clean-wifi-profiles)  CLEAN_WIFI=1 ;;
    --cn-mirror)            CN_MIRROR=1 ;;
    --keep-desktop)         KEEP_DESKTOP=1 ;;
    -h|--help)              usage ;;
    *) die "不认识的参数：$arg（用 --help 看用法）" ;;
  esac
done

# ---------------------------------------------------------------- 0. 环境检查
[ "$(id -u)" -eq 0 ] || die "请用 sudo 运行：sudo $0 $*"

. /etc/os-release
case "${VERSION_CODENAME:-}" in
  bookworm|bullseye) ;;
  *) warn "当前系统是 ${PRETTY_NAME:-未知}，脚本是针对 Bookworm 验证的，继续但可能有问题" ;;
esac

MODEL="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo unknown)"
case "$MODEL" in
  *Raspberry\ Pi*) log "检测到主板：$MODEL" ;;
  *) die "这看起来不是树莓派：$MODEL" ;;
esac

[ -d "$HERE/home" ] && [ -d "$HERE/systemd" ] || die "脚本目录不完整（缺 home/ 或 systemd/），请在仓库的 raspberry/ 目录里运行"

[ -d "$PI_HOME" ] || die "$PI_HOME 不存在。systemd 单元里的路径写死在 /home/pi，请用用户名 pi 刷系统（或设置 LYRICHUD_USER=pi 之外的路径并自行改 unit）"
if [ "$PI_USER" != "pi" ]; then
  warn "当前用户是 $PI_USER，但 systemd/*.service 里的路径是 /home/pi，请自行确认可用"
fi
log "开始安装（dry-run=$DRY_RUN, write-boot=$WRITE_BOOT）"

# ---------------------------------------------------------------- 1. 依赖包
log "1/8 安装系统依赖"
PKGS="chromium xinit xserver-xorg xserver-xorg-video-fbdev x11-xserver-utils \
      python3-venv python3-pip bluez network-manager fonts-dejavu-core"
if [ "$DRY_RUN" = 1 ]; then
  printf '    + apt-get install -y %s\n' "$PKGS"
else
  MISSING=""
  for p in $PKGS; do
    dpkg -s "$p" >/dev/null 2>&1 || MISSING="$MISSING $p"
  done

  if [ -z "$MISSING" ]; then
    log "   依赖已齐全，跳过 apt"
  else
    log "   缺少：$MISSING"
    export DEBIAN_FRONTEND=noninteractive
    # 强制 IPv4：很多国内网络 DNS 只回 AAAA，apt 会卡在 IPv6 上等到超时
    APT_OPTS="-o Acquire::ForceIPv4=true -o Acquire::http::Timeout=20 -o Acquire::Retries=2"

    if [ "$CN_MIRROR" = 1 ]; then
      if grep -q 'mirrors.ustc.edu.cn' /etc/apt/sources.list 2>/dev/null; then
        log "   已经是 USTC 源，跳过换源"
      else
        backup /etc/apt/sources.list
        sed -i 's|http://raspbian.raspberrypi.com/raspbian/|https://mirrors.ustc.edu.cn/raspbian/raspbian/|g' /etc/apt/sources.list
        log "   已把 raspbian 源切到 USTC 镜像"
      fi
    fi

    if ! timeout 600 apt-get $APT_OPTS update -qq; then
      warn "apt-get update 超时或失败，继续尝试安装（可能用已有索引）"
      warn "国内网络可以加 --cn-mirror 换 USTC 源"
    fi
    timeout 900 apt-get $APT_OPTS install -y --no-install-recommends $MISSING >/dev/null \
      || die "依赖安装失败，请检查网络后重试（可试 --cn-mirror）"
  fi
fi

# ---------------------------------------------------------------- 2. 网页与脚本
log "2/8 部署 kiosk 页面与脚本到 /home/pi"
run install -d -o $PI_USER -g $PI_USER "$PI_HOME/js"
cpf "$HERE/home/index.html"      "$PI_HOME/index.html"  0644
cpf "$HERE/home/pixel12.woff2"   "$PI_HOME/pixel12.woff2" 0644
for f in "$HERE"/home/js/*; do
  cpf "$f" "$PI_HOME/js/$(basename "$f")" 0644
done
cpf "$HERE/home/kiosk.sh"  "$PI_HOME/kiosk.sh"  0755
cpf "$HERE/home/mirror.sh" "$PI_HOME/mirror.sh" 0755
cpf "$HERE/home/xinitrc"   "$PI_HOME/.xinitrc"  0644
[ "$DRY_RUN" = 1 ] || chown -R $PI_USER:$PI_USER "$PI_HOME/js" "$PI_HOME/index.html" "$PI_HOME/pixel12.woff2" \
                                   "$PI_HOME/kiosk.sh" "$PI_HOME/mirror.sh" "$PI_HOME/.xinitrc"

# ---------------------------------------------------------------- 3. Python 服务代码
log "3/8 部署 Flask 与 BLE 服务代码到 $CODE_DIR"
run install -d -o $PI_USER -g $PI_USER "$CODE_DIR"
cpf "$HERE/code/flask_app.py" "$CODE_DIR/flask_app.py" 0644
cpf "$HERE/code/ble.py"       "$CODE_DIR/ble.py"       0644
[ "$DRY_RUN" = 1 ] || chown -R $PI_USER:$PI_USER "$CODE_DIR" 2>/dev/null || true

# ---------------------------------------------------------------- 4. 虚拟环境
log "4/8 准备 Python 虚拟环境 $VENV"
if [ "$DRY_RUN" = 1 ]; then
  echo "    + python3 -m venv $VENV && $VENV/bin/pip install -r code/requirements.txt"
else
  [ -x "$VENV/bin/python" ] || python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --timeout 30 --retries 2 --upgrade pip
  "$VENV/bin/pip" install -q --timeout 30 --retries 2 -r "$HERE/code/requirements.txt"
  chown -R $PI_USER:$PI_USER "$VENV"
fi

# ---------------------------------------------------------------- 5. X 相关配置
log "5/8 配置 X（fbdev 指到 /dev/fb1、隐藏鼠标、防熄屏）"
run install -d /etc/X11/xorg.conf.d
for f in "$HERE"/boot/xorg.conf.d/*.conf; do
  cpf "$f" "/etc/X11/xorg.conf.d/$(basename "$f")" 0644
done
backup /etc/X11/xinit/xserverrc
if [ "$DRY_RUN" = 1 ]; then
  echo "    + 写入 /etc/X11/xinit/xserverrc（加 -nocursor）"
else
  cat > /etc/X11/xinit/xserverrc <<'EOF'
#!/bin/sh
# LyricHud: -nocursor 让 SPI 屏上不出现鼠标指针
exec /usr/bin/X -nocursor -nolisten tcp "$@"
EOF
  chmod 0755 /etc/X11/xinit/xserverrc
fi

# ---------------------------------------------------------------- 6. systemd 服务
log "6/8 安装并启用 systemd 服务"
for f in "$HERE"/systemd/*.service; do
  cpf "$f" "/etc/systemd/system/$(basename "$f")" 0644
done
run systemctl daemon-reload
run systemctl enable flask_app.service lyrichud-ble.service kiosk.service

# ---------------------------------------------------------------- 7. 桌面会话
if [ "$KEEP_DESKTOP" = 1 ]; then
  log "7/8 保留 LightDM 桌面（注意：它会和 kiosk 抢 /dev/fb1）"
else
  log "7/8 禁用 LightDM 桌面（避免和 kiosk 抢同一块 framebuffer）"
  if [ "$DRY_RUN" = 1 ]; then
    echo "    + systemctl disable --now lightdm"
  elif systemctl list-unit-files | grep -q '^lightdm.service'; then
    systemctl disable --now lightdm >/dev/null 2>&1 || true
  fi
fi

# ---------------------------------------------------------------- 8. boot 分区
if [ "$WRITE_BOOT" = 1 ]; then
  log "8/8 写入 /boot/firmware 的屏幕配置"
  [ -d "$BOOT" ] || die "$BOOT 不存在，这不像 Bookworm 的树莓派系统"

  # 掉电 / IO 错误后内核会把 vfat 挂成只读（errors=remount-ro），先试着改回来
  if [ "$DRY_RUN" = 0 ]; then
    if ! touch "$BOOT/.lyrichud_wtest" 2>/dev/null; then
      warn "$BOOT 当前是只读的，尝试重新挂载为可写"
      mount -o remount,rw "$BOOT" 2>/dev/null || true
      if ! touch "$BOOT/.lyrichud_wtest" 2>/dev/null; then
        BOOTDEV="$(findmnt -no SOURCE "$BOOT" || echo /dev/mmcblk0p1)"
        die "$BOOT 仍然只读。请手动执行：
      sudo fsck.vfat -a $BOOTDEV
      sudo mount -o remount,rw $BOOT
    然后重新运行本脚本。"
      fi
    fi
    rm -f "$BOOT/.lyrichud_wtest" 2>/dev/null || true
  fi

  backup "$BOOT/config.txt"
  if [ "$DRY_RUN" = 0 ]; then
    # 关掉 vc4-kms-v3d，让 X 走 fbdev（只改第一处未注释的）
    sed -i '0,/^dtoverlay=vc4-kms-v3d/s|^dtoverlay=vc4-kms-v3d|#dtoverlay=vc4-kms-v3d|' "$BOOT/config.txt"

    if grep -q '^dtoverlay=fbtft' "$BOOT/config.txt" && ! grep -q '# ===== LyricHud SPI display' "$BOOT/config.txt"; then
      # 已经手工配过屏（老机器），不要再追加一份，否则会加载两次 overlay
      log "   config.txt 里已经有 fbtft overlay，跳过追加（不重复加载）"
    else
      # 删掉上次生成的块（如果有），保证幂等
      sed -i '/# ===== LyricHud SPI display/,/# ===== LyricHud end =====/d' "$BOOT/config.txt"
      { echo; cat "$HERE/boot/config.txt.append"; } >> "$BOOT/config.txt"
      log "   已追加 SPI 屏配置块"
    fi
  else
    echo "    + 注释掉 vc4-kms-v3d；若 config.txt 无 fbtft 则追加 boot/config.txt.append"
  fi

  backup "$BOOT/cmdline.txt"
  if [ "$DRY_RUN" = 0 ]; then
    sed -i 's/\bconsole=tty1\b/console=tty3/' "$BOOT/cmdline.txt"
    grep -q 'fbcon=map:1'        "$BOOT/cmdline.txt" || sed -i 's/$/ fbcon=map:1/'        "$BOOT/cmdline.txt"
    grep -q 'consoleblank=0'     "$BOOT/cmdline.txt" || sed -i 's/$/ consoleblank=0/'     "$BOOT/cmdline.txt"
  else
    echo "    + 修改 cmdline.txt：console=tty3 / fbcon=map:1 / consoleblank=0"
  fi
else
  log "8/8 跳过 /boot/firmware（需要时加 --write-boot）"
fi

# ---------------------------------------------------------------- 9. 可选：Wi-Fi
if [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PSK" ]; then
  log "附加：写入 Wi-Fi 配置 $WIFI_SSID"
  if [ "$DRY_RUN" = 1 ]; then
    echo "    + /etc/NetworkManager/system-connections/lyrichud-wifi.nmconnection"
  else
    install -d /etc/NetworkManager/system-connections
    CONN="$WIFI_SSID"
    UUID="$(cat /proc/sys/kernel/random/uuid)"
    cat > "/etc/NetworkManager/system-connections/lyrichud-wifi.nmconnection" <<EOF
[connection]
id=$CONN
uuid=$UUID
type=wifi
autoconnect=true

[wifi]
mode=infrastructure
ssid=$WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$WIFI_PSK

[ipv4]
method=auto

[ipv6]
method=disabled
EOF
    chmod 0600 "/etc/NetworkManager/system-connections/lyrichud-wifi.nmconnection"
    chown root:root "/etc/NetworkManager/system-connections/lyrichud-wifi.nmconnection"
    systemctl reload NetworkManager 2>/dev/null || true
  fi
fi

if [ "$CLEAN_WIFI" = 1 ]; then
  log "附加：清理历史热点配置 AndroidShare_*"
  if [ "$DRY_RUN" = 1 ]; then
    echo "    + rm -f /etc/NetworkManager/system-connections/AndroidShare_*.nmconnection"
  else
    rm -f /etc/NetworkManager/system-connections/AndroidShare_*.nmconnection
  fi
fi

# ---------------------------------------------------------------- 10. 启动 & 自检
if [ "$DRY_RUN" = 0 ]; then
  log "启动服务"
  systemctl restart flask_app.service
  systemctl restart lyrichud-ble.service
  systemctl restart kiosk.service
  sleep 6

  echo
  log "===== 自检 ====="
  printf '%-22s %s\n' "fb1（SPI 屏）"  "$([ -e /dev/fb1 ] && cat /sys/class/graphics/fb1/name || echo '缺失 —— 需要 --write-boot 并重启')"
  printf '%-22s %s\n' "flask_app.service"  "$(systemctl is-active flask_app.service)"
  printf '%-22s %s\n' "lyrichud-ble.service" "$(systemctl is-active lyrichud-ble.service)"
  printf '%-22s %s\n' "kiosk.service"      "$(systemctl is-active kiosk.service)"
  printf '%-22s %s\n' "5588 端口"          "$(ss -lntp 2>/dev/null | grep -q ':5588' && echo 监听中 || echo 未监听)"
  printf '%-22s %s\n' "本机 IP"            "$(hostname -I 2>/dev/null)"
  echo
  log "完成。若刚刚加了 --write-boot，请重启一次：sudo reboot"
else
  log "dry-run 结束，未做任何改动"
fi