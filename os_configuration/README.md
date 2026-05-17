# Phase 2 & 3: OS Configuration

This phase transforms a headless Fedora server into a fully configured Cinnamon desktop system with user accounts, optimized packages, and personal preferences.

For installation details, see [os_installation/README.md](../os_installation/README.md). For design reasoning, see [DESIGN.md](../DESIGN.md).

## Overview

**Phase 2** runs after the first reboot into the newly installed headless system. The entry point is `./autorun.sh`, which iterates over all `./0*.sh` scripts in lexicographic order. All output is logged to `autorun.log`. Must be run as root. Ends with an automatic reboot (script 099).

**Phase 3** is manual. After rebooting into the GUI, run `200_restore_cinnamon_settings.sh` and `300_make_final_btrfs_snapshot.sh` as root from this directory.

### Why Two Phases?

- **Phase 2 (0xx scripts)**: System-level configuration that does not require a GUI session. Runs in TUI (TTY login). Installs Cinnamon, configures the system, creates user accounts.
- **Phase 3 (2xx/3xx scripts)**: User-level configuration that requires a running Cinnamon session. The `cinnamon --replace` in script 200 needs a display server. Pinned apps configuration needs Cinnamon's spice config files, which are created on first GUI login.

The reboot between phases ensures all services (display manager, NetworkManager, etc.) are running properly before Phase 3 configures them.

## Files in This Directory

| File | Purpose |
|---|---|
| `autorun.sh` | Phase 2 entry point; runs all `0*.sh` scripts sequentially |
| `user_conf.sh` | User configuration (username, display name). Sourced by scripts 070, 071, 200 |
| `cinnamon_desktop_backup` | dconf dump of Cinnamon settings. Loaded by script 200 |
| `xed_configuration_backup` | dconf dump of xed editor preferences. Loaded by script 200 |
| `DATA/terminator/config` | Terminator terminal emulator configuration (infinite scrollback). Copied by scripts 071 and 200 |

## Configuration (`user_conf.sh`)

```bash
USER="lod"
USER_PRETTY="Hvezdna lod"
```

| Variable | Description |
|---|---|
| `USER` | Unix username for the primary account |
| `USER_PRETTY` | Display name / GECOS field (supports UTF-8) |

Sourced by scripts that need to operate on the user account.

## Script-by-Script Reference

### 000 -- First BTRFS Snapshot

Creates the baseline snapshot before any configuration changes.

```bash
mount --target=/mnt/BTRFS-ROOT
btrfs subvolume snapshot -r boot RO-BACKUP-01-minimal_headless_server_setup_finished
```

This is the "vanilla server" checkpoint -- minimal OS, no GUI, no configuration.

### 001 -- Restrict dmesg

```bash
dmesg -n 1
```

Sets console log level to emergency only. Without this, kernel messages (USB events, network state changes) interrupt the TUI during interactive scripts, especially the hostname prompt in 010.

### 010 -- Set Hostname

Interactive prompt for the machine hostname:

```bash
bind 'set enable-bracketed-paste off' 2>/dev/null
read -p "Set this machine HOSTNAME: " -e -i "FARAMOS-NTB-" new_hostname
echo "$new_hostname" > /etc/hostname
```

The `bind` command disables readline's bracketed paste mode. Without it, pasting text into the prompt includes escape sequences (`\e[200~...\e[201~`) that end up in the hostname.

### 011 -- Display IP on TUI Login

Writes the LAN IP address to `/etc/issue` so it appears on the TTY login screen:

```bash
LAN=$(ip -br a | grep enp | awk '{print $1}')
echo -e "IP LAN: \4{$LAN}" > /etc/issue
```

Uses systemd's `\4{interface}` escape to display the IPv4 address dynamically.

### 012 -- Limit Journal Size

```bash
sed -i 's|#SystemMaxUse=|SystemMaxUse=50M|g' /usr/lib/systemd/journald.conf
systemctl restart systemd-journald
```

Caps the systemd journal at 50 MB. Fleet machines are workstations where only the current and previous boot logs matter. Gigabytes of persistent logs are unnecessary overhead.

### 013 -- Set Locale and Timezone

```bash
localectl set-locale LANG=en_US.UTF-8
localectl set-x11-keymap cz,us " " , grp:alt_shift_toggle
ln -s /usr/share/zoneinfo/Europe/Prague /etc/localtime
systemctl enable --now systemd-timesyncd
```

| Setting | Value |
|---|---|
| Language | `en_US.UTF-8` |
| Keyboard layouts | Czech (primary), US (secondary) |
| Layout toggle | Alt+Shift |
| Timezone | Europe/Prague |
| NTP | `systemd-timesyncd` enabled |

### 030 -- Enable Additional Repositories

```bash
dnf install rpmfusion-free-release rpmfusion-nonfree-release fedora-workstation-repositories fedora-repos-rawhide
dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
```

| Repository | Purpose |
|---|---|
| RPM Fusion (free + nonfree) | Multimedia codecs, proprietary drivers |
| fedora-workstation-repositories | Enables Chrome, PyCharm, etc. repos (disabled by default) |
| fedora-repos-rawhide | Enables Rawhide repo (disabled by default, useful for testing) |
| Brave Browser | Official RPM repository |

### 031 -- Install GUI

The largest and most complex script. Three phases:

**1. Install Cinnamon DE:**
```bash
dnf group install cinnamon-desktop
```

**2. Remove bloatware (~490 MiB):**

Two `dnf remove` calls strip unnecessary packages while protecting essential ones via `-x cinnamon -x xorg-x11-* -x lsof -x boost* -x chrony -x "flatpak*"`.

Phase 1 removes: dnfdragora, pidgin, xfburn, thunderbird, xawtv, shotwell, ImageMagick, anaconda, trousers, yelp, redshift, mpv, gnome-calculator, gnome-calendar, plymouth, fwupd, PackageKit, deltarpm, enchant, exiv2, fortune-mod, geolite, hexchat, kpartx, nilfs-utils, onboard, pcsc-lite, evolution.

Phase 2 removes: CJK input methods (ibus-anthy, ibus-chewing, ibus-hangul, ibus-libpinyin, ibus-m17n, ibus-typing-booster), accessibility TTS (speech-dispatcher, espeak-ng, flite), unused themes/data (paper-icon-theme, libmateweather-data, unicode-ucd, cldr-emoji-annotation).

Six packages are bloat but cannot be removed due to hard dependencies. See [DESIGN.md — Cinnamon Optimization](../DESIGN.md#cinnamon-de-optimization).

**3. Audio and multimedia:**

```bash
dnf install alsa-utils pulseaudio-utils alsa-sof-firmware
dnf install --allowerasing vlc audacity ffmpeg-libs ffmpeg
dnf install --allowerasing gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly libavcodec-freeworld vlc-plugins-freeworld
```

- `alsa-sof-firmware`: Sound Open Firmware, needed for modern Intel audio
- `--allowerasing`: Required for RPM Fusion codec packages that replace Fedora's restricted versions

### 032 -- Install Favourite Software

```bash
dnf install tree tldr curl tar git zip unzip unrar openssl wget nano terminator ntfs-3g pip flatpak ...
dnf install brave-browser
dnf install EmptyEpsilon
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.discordapp.Discord
```

| Category | Packages |
|---|---|
| CLI tools | tree, tldr, curl, tar, git, zip/unzip/unrar, openssl, wget, nano, rsync |
| Terminal | terminator |
| System | ntfs-3g, pip, flatpak, dnf-plugin-system-upgrade, gnome-software, speedtest-cli |
| Fonts | google-noto-color-emoji (all variants), dejavu-fonts-all |
| Browser | Brave |
| Games | puzzles (SGT collection), EmptyEpsilon, cmatrix, cool-retro-term |
| Flatpak | Discord (from Flathub) |

### 033 -- Install WiFi Drivers

```bash
dnf install iwlwifi-mvm-firmware iwlwifi-dvm-firmware
```

| Package | Coverage |
|---|---|
| `iwlwifi-mvm-firmware` | Modern Intel WiFi adapters (7260+) |
| `iwlwifi-dvm-firmware` | Older Intel WiFi adapters (pre-7260) |

Alternatives noted in comments: `iwlegacy-firmware` for very old adapters, `broadcom-wl` for Broadcom (taints kernel).

Requires reboot to take effect.

### 050 -- Root Shell Customization

Appends to `/root/.bashrc`:

- **Default editor**: nano (`EDITOR`, `VISUAL`, `UAEDITOR`)
- **Aliases**: `L` (ls -Alh), `IP` (ip -c a), `N` (nano), `GS`/`GCH`/`GBA` (git shortcuts), `DMESG` (error/warning watch), `MOUNT` (formatted table)
- **HELP alias**: Multi-line reference card covering SSH key auth, firewall rules, sudoers, login auditing, Terminator shortcuts, Python venv, BTRFS snapshot commands, systemctl targets

### 051 -- Infinite Bash History

Creates `/etc/profile.d/z_infinite_bash_history.sh` (system-wide, `z_` prefix ensures it loads last):

```bash
HISTSIZE=-1       # Unlimited in-memory history
HISTFILESIZE=-1   # Unlimited history file on disk
```

### 052 -- Disable SSH

```bash
systemctl disable sshd || true
```

Security posture: fleet machines are workstations, not servers. SSH is enabled on-demand when needed. The `|| true` prevents failure if sshd is not installed.

### 053 -- Disable Bluetooth

```bash
systemctl disable bluetooth || true
```

Power saving and reduced attack surface. Bluetooth is enabled on-demand per device.

### 070 -- Create User

```bash
source ./user_conf.sh
useradd "$USER"
usermod -c "$USER_PRETTY" "$USER"
echo "$USER:$USER" | chpasswd
usermod -a -G wheel "$USER"
```

- Username and display name come from `user_conf.sh`
- Initial password = username (change after setup)
- Added to `wheel` group -- required by polkit rules for Bluetooth GUI (BlueZ) to control BT on/off state. Without `wheel`, BlueZ spams authentication popups after every login

### 071 -- Terminator Scrollback Config

```bash
source ./user_conf.sh
cp -a ./DATA/terminator /home/"$USER"/.config/
chown -R "$USER":"$USER" /home/"$USER"/.config/
```

Deploys pre-configured Terminator with infinite scrollback for the user.

### 099 -- Reboot

```bash
reboot
```

End of Phase 2. The system reboots into Cinnamon's display manager (graphical login).

### 200 -- Restore Cinnamon Settings (Phase 3, Manual)

Must be run as root after the first GUI login. Operates on the user's session via `su -c`:

**1. Cinnamon desktop settings:**
```bash
su -c "dconf load /org/cinnamon/ < ./cinnamon_desktop_backup" "$USER"
su -c "cinnamon --replace >/dev/null 2>&1 &" "$USER"
```

Restores panel layout, applets, effects, hotcorners, icon sizes, startup animation settings from the dconf backup. Restarts Cinnamon to apply.

**2. Xed editor:**
```bash
su -c "dconf load /org/x/editor/preferences/ < ./xed_configuration_backup" "$USER"
```

Restores xed preferences: auto-indent, bracket matching, line numbers, highlight current line, dark theme (cobalt).

**3. Terminator config:**
```bash
cp -a ./DATA/terminator "/home/$USER/.config"
chown -R "$USER:$USER" "/home/$USER/.config/terminator"
```

**4. Locale for non-root user:**
```bash
su -c "localectl set-locale LANG=en_US.UTF-8" "$USER"
su -c 'localectl set-x11-keymap cz,us " " , grp:alt_shift_toggle' "$USER"
```

**5. Pinned taskbar applications:**
```bash
jq '.["pinned-apps"].default = ["nemo.desktop", "brave-browser.desktop", "terminator.desktop", "com.discordapp.Discord.desktop:flatpak"]' "$CONFIG" > /tmp/config.json
```

Modifies the grouped-window-list Cinnamon applet configuration to pin: Nemo (file manager), Brave, Terminator, Discord (flatpak).

### 300 -- Final BTRFS Snapshot (Phase 3, Manual)

```bash
mount --target=/mnt/BTRFS-ROOT
btrfs subvolume snapshot -r boot RO-BACKUP-02-GUI_setup_finished
```

The "golden image" checkpoint -- complete OS with GUI, software, and user configuration. This is the first rollback target for any future issues.

## Execution Dependencies

```
030 (repos) ──→ 031 (Cinnamon needs RPM Fusion for codecs)
           ├──→ 032 (Brave needs Brave repo)
           └──→ 033 (firmware from Fedora repos)

031 (GUI) ────→ 200 (Cinnamon settings require Cinnamon installed)

070 (user) ───→ 071 (Terminator config needs user's home directory)
           └──→ 200 (Cinnamon settings loaded for the user)

099 (reboot) ─→ 200 (Cinnamon session must be running)

200 (settings) → 300 (final snapshot should capture fully configured state)
```

The numbering scheme enforces this ordering: `autorun.sh` globs `./0*.sh` which sorts lexicographically.

## Adding New Scripts

Use the numbering gaps to insert new scripts in the correct execution position:

| Gap | Available range |
|---|---|
| After snapshot, before hostname | 002-009 |
| After locale, before repos | 014-029 |
| After WiFi, before root shell | 034-049 |
| After Bluetooth, before user | 054-069 |
| After Terminator, before reboot | 072-098 |

Phase 2 scripts (`0*.sh`) are run automatically by `autorun.sh`. Phase 3 scripts (`2*.sh`, `3*.sh`) are run manually and must be documented in the [Usage](../README.md#usage) section of the root README.
