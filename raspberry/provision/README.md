# 空白卡一键点亮（首次开机自动安装）

这条路适合：**手上只有一张新卡 + 树莓派，不想插键盘显示器，开机就装好。**

原理：把安装包放到卡的 `bootfs` 分区，再用 `systemd.run=` 让系统在第一次开机时自动执行 `install.sh `（这个机制就是 Raspberry Pi Imager 自己用的那套）。

---

## 前提

| 项 | 要求 |
| --- | --- |
| 硬件 | Raspberry Pi 4B（3B+/5 也行，但屏幕 overlay 的引脚按 4B 写的） |
| 镜像 | **Raspberry Pi OS Bookworm 64-bit**（2024-11 及相近版本） |
| 用户名 | **必须是 `pi`**（systemd 单元里的路径写死在 `/home/pi`） |
| 屏幕 | ST7789V 240×240 SPI，接线见 [../HARDWARE.md](../docs/HARDWARE.md) |

---

## 操作步骤

### 1. 刷镜像
用 Raspberry Pi Imager 刷 Bookworm 64-bit。在 Imager 的「自定义」里：
- 用户名设 `pi`，设个密码
- **勾上「启用 SSH」**（方便以后远程修）
- Wi-Fi 可以先不填，后面用 `lyrichud.conf` 配

刷完**先别拔卡**（或者刷完再插回电脑）。

### 2. 把安装包丢进 boot 分区

把本仓库的 `raspberry/` 整个目录复制到卡的 `bootfs` 分区，路径必须是：

```
<bootfs盘符>:\lyrichud\raspberry\        ← install.sh、home/、systemd/ 等
<bootfs盘符>:\lyrichud\firstrun.sh       ← 本目录下的 firstrun.sh
<bootfs盘符>:\lyrichud\lyrichud.conf     ← 可选，自动连 Wi-Fi
```

> Windows 上 `bootfs` 就是「此电脑」里那个 512MB 的小分区。

### 3. 写 Wi-Fi（可选）

把 [lyrichud.conf.example](lyrichud.conf.example) 复制成 `lyrichud.conf`，改两行：

```
WIFI_SSID=你家WiFi
WIFI_PSK=密码
```

不填也行：用网线，或者事后自己配。

### 4. 打上一次性启动钩子

**Windows**：在 `lyrichud\raspberry\provision\` 目录里双击运行

```
patch-cmdline.bat I:
```

（`I:` 换成你 `bootfs` 的盘符）

**Linux / macOS**：

```bash
./patch-cmdline.sh /media/$USER/bootfs
```

它会备份 `cmdline.txt`，然后把
`systemd.run=/boot/firmware/lyrichud/firstrun.sh` 追加进去。

### 5. 插卡开机，等 5 分钟

首次开机会依次：装依赖 → 建 venv → 装服务 → 写屏幕配置 → **自动重启一次**。

屏幕上先是黑的（正常，`fsck` + 安装中），重启后才会出现歌词界面。

### 6. 装完检查

- 屏幕：出现绿色边框的歌词页（没放歌时是暂停图标）
- 卡里：`bootfs:\lyrichud\report.txt` 记录了全过程，最后一行应该是 `firstrun 结束 OK`
- 手机 App：状态栏里「外设链接」会变绿

---

## 出问题怎么办

| 现象 | 先看 |
| --- | --- |
| 开机一直黑屏 | 等 10 分钟；还黑就拔卡看 `lyrichud\report.txt` |
| 报告里有 `apt-get` 报错 | 树莓派没联网，用网线重来一次，或在 `lyrichud.conf` 里配好 Wi-Fi |
| 报告里 `WIFI` 连不上 | SSID 有空格/中文会导致 nmcli 解析失败，换成纯英文 SSID 试试 |
| 报告正常但屏幕黑 | `config.txt` 里的 overlay 没生效：确认 `bootfs:\config.txt` 末尾有 `# ===== LyricHud SPI display =====` 段落，然后重启 |

⚠️ **报告文件里可能包含你的 Wi-Fi 名称**，发给别人前先看一眼。

---

## 不想用首启方案？

那就正常装上系统、开机、联网、开 SSH，然后：

```bash
git clone https://github.com/1053278842/LyricsDisplay.git
cd LyricsDisplay/raspberry
sudo ./install.sh --write-boot
sudo reboot
```

效果完全一样，只是要手动敲两条命令。详见 [../docs/SETUP.md](../docs/SETUP.md)。