# Phase 1: OS Installation

This phase runs from the Fedora Live USB environment. It transforms a blank disk into a bootable headless Fedora server with BTRFS, a custom GRUB chain, and BLS boot entries.

For the design reasoning behind each step, see [DESIGN.md](../DESIGN.md).

## Overview

- **Entry point**: `autorun.sh` (repo root) calls `python3 -u main.py` (unbuffered output)
- **Logging**: All output is tee'd to `os_installation.log`, which is copied into the installed system at `/root/` on completion
- **Timing**: Elapsed time displayed at the end (~6 minutes on NVMe)
- **Root requirement**: Enforced by `lib.py` at import time

## Files in This Directory

| File | Language | Purpose |
|---|---|---|
| `main.py` | Python | Main installation script, executed sequentially top-to-bottom |
| `config.py` | Python | User-configurable variables: disk, Fedora release, device name |
| `lib.py` | Python | `shell_cmd()` subprocess wrapper with error handling and colored output |
| `cleanup.py` | Python | Pre-installation cleanup: unmounts all partitions on target disk |
| `GRUB_BTRFS/etc-default-grub` | GRUB config | `/etc/default/grub` settings (1s timeout, BLS, no UUIDs) |
| `GRUB_BTRFS/EFI-grub.cfg` | GRUB config | Stage 2 trampoline for EFI partition |
| `GRUB_BTRFS/grub.cfg` | GRUB config | Stage 3 main config with BLS loading |

## Configuration (`config.py`)

| Variable | Example | Description |
|---|---|---|
| `fedora_release` | `44` | Target Fedora release number |
| `disk` | `nvme0n1` | Block device name without `/dev/` prefix |
| `device_name` | `FEDORA-FROM-SCRATCH` | Hostname written to `/etc/hostname` |
| `mountpoint_path` | `/mnt/FEDORA_FROM_SCRATCH` | Where the target filesystem is mounted during installation. Rarely needs changing |

`disk_path` is derived automatically as `/dev/{disk}`.

This file varies between branches -- it is the primary per-device configuration point.

## Step-by-Step Walkthrough

### Partition Path Detection

Different disk types use different partition naming schemes:

| Disk type | Example | Partition 1 | Partition 2 |
|---|---|---|---|
| `sd*`, `hd*`, `xvd*` | `sda` | `sda1` | `sda2` |
| `nvme*`, `vd*`, `mmcblk*` | `nvme0n1` | `nvme0n1p1` | `nvme0n1p2` |

A random 6-character uppercase alphanumeric hash is generated for filesystem labels (see [DESIGN.md — Label Naming Convention](../DESIGN.md#label-naming-convention)).

### Prerequisites

```python
chronyc tracking           # Verify system clock is synced (for HTTPS cert validation)
dnf install util-linux coreutils btrfs-progs dosfstools  # Partitioning and FS tools
```

### Cleanup (`cleanup.py`)

Defensively clears the slate before partitioning:

```python
swapoff -a                           # Disable all swaps
swapoff {disk_path}*                 # Ensure target disk swaps are off
umount -l {disk_path}*               # Lazy unmount all target disk partitions
umount -R -c {mountpoint_path}/*     # Recursive unmount of mountpoint tree
sync ; sleep 3                       # Wait for pending I/O
```

All commands run with `ignore_error_code=True` -- failures are expected on first run when nothing is mounted.

### Partitioning

Creates a GPT partition table with two partitions via `sfdisk`:

```python
echo "label: gpt" | sfdisk {disk_path}
udevadm settle                       # Wait for udev to process the new table
```

| Partition | Size | Type | Purpose |
|---|---|---|---|
| 1 | 500 MB | `C12A7328-...` (EFI) | EFI System Partition |
| 2 | 99 TB (clamped to disk) | Default | BTRFS system partition |

The 99 TB size is a trick: `sfdisk` clamps to the remaining disk space.

### Filesystem Creation

```python
mkfs.vfat -n "EFI-{hash}" {partition1}        # FAT32 with label
mkfs.btrfs -f -L "BTRFS-{hash}" {partition2}  # BTRFS with label, -f forces overwrite
```

### BTRFS Subvolume Setup

```python
mount -t btrfs {partition2} {mountpoint}          # Mount BTRFS root
btrfs subvolume create {mountpoint}/root          # Create OS subvolume
cd {mountpoint} ; ln -s "root" "boot"             # Create boot symlink
umount {mountpoint}
mount -t btrfs -o noatime,subvol="boot" {partition2} {mountpoint}  # Remount via symlink
```

After this, `{mountpoint}` is the OS subvolume accessed through the `boot` symlink. See [DESIGN.md — Boot Symlink Design](../DESIGN.md#btrfs-subvolume--boot-symlink-design).

### Mount Tree Assembly

```python
mkdir -p {mountpoint}/boot/efi/
mount -o noatime {partition1} {mountpoint}/boot/efi/    # EFI partition

mkdir {mountpoint}/sys {mountpoint}/proc {mountpoint}/dev
chcon --reference=/dev {mountpoint}/dev                  # SELinux context fix (rhbz#1467103, rhbz#1714026)

mount -t sysfs none {mountpoint}/sys         # Virtual FS for package scriptlets
mount -t proc  none {mountpoint}/proc
mount -o bind  /dev {mountpoint}/dev
```

The bind mounts are required by package scriptlets that assume `/dev/*`, `/sys/*`, and `/proc/*` exist.

### Custom Repo Creation

A temporary repo file is written to `/etc/yum.repos.d/fedora-custom.repo` on the **live system** (not the installroot):

```ini
[fedora-custom]
name=fedora-custom
enabled=0
gpgcheck=0
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-{release}&arch=$basearch

[fedora-updates-custom]
name=fedora-updates-custom
enabled=0
gpgcheck=0
metalink=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f{release}&arch=$basearch
```

Both repos are disabled by default and enabled explicitly in the first DNF call. This decouples the installed Fedora version from the live USB version. See [DESIGN.md — DNF Installroot](../DESIGN.md#dnf-installroot--custom-repo).

### Package Installation (3 DNF Calls)

All calls share common arguments: `--releasever={release} --installroot={mountpoint} -y --nogpgcheck`

**Call 1 -- Core system** (uses custom repos via `--use-host-config`):
- `@core` group
- `btrfs-progs` (needed by grub2-common and kernel-core scriptlets)
- `glibc-langpack-en glibc-langpack-cs` (locale data for glibc, ~5 MiB vs 227 MiB for glibc-all-langpacks)
- `langpacks-en langpacks-cs` (application-level translations)

This call installs `fedora-release`, populating the installroot's own `/etc/yum.repos.d/`.

**Call 2 -- Custom core packages** (uses installroot's own repos):
- `nano tree bash-completion git wget`

**Call 3 -- Kernel** (uses installroot's own repos):
- `kernel kernel-core kernel-modules`
- `-x amd-gpu-firmware -x nvidia-gpu-firmware` (GPU firmware excluded -- not needed in headless server phase; GPU firmware is handled by initramfs or installed later)

### DNS and Hostname

```python
cp --remove-destination /etc/resolv.conf {mountpoint}/etc/    # DNS resolution for chroot operations
echo {device_name} > {mountpoint}/etc/hostname
```

`systemd-resolved` takes over DNS on first boot.

### fstab Generation

Written directly to `{mountpoint}/etc/fstab` with three entries:

```
LABEL=EFI-{hash}    /boot/efi/        vfat   noatime,defaults              0  2
LABEL=BTRFS-{hash}  /                 btrfs  noatime,subvol=boot           0  0
LABEL=BTRFS-{hash}  /mnt/BTRFS-ROOT   btrfs  noatime,subvol=/,X-mount.mkdir,noauto  0  0
```

- Root mount uses `subvol=boot` (the symlink)
- The `/mnt/BTRFS-ROOT` entry is a convenience mount for snapshot management (`noauto` = not mounted at boot)
- `X-mount.mkdir` creates the mountpoint directory automatically

### GRUB Setup

**Copy `/etc/default/grub`**:
```python
cp ./GRUB_BTRFS/etc-default-grub {mountpoint}/etc/default/grub
```

**Install GRUB packages**:
```python
dnf install grub2-efi-x64 grub2-efi-x64-modules shim
```

**Deploy EFI grub.cfg (trampoline)**:
```python
cp ./GRUB_BTRFS/EFI-grub.cfg {mountpoint}/boot/efi/EFI/fedora/grub.cfg
sed -i "s/REPLACE-THIS-WITH-DISK-LABEL/BTRFS-{hash}/g" {mountpoint}/boot/efi/EFI/fedora/grub.cfg
cp {mountpoint}/boot/efi/EFI/fedora/grub.cfg {mountpoint}/boot/efi/EFI/fedora/grub.cfg-BACKUP
```

The placeholder `REPLACE-THIS-WITH-DISK-LABEL` in the template is replaced with the actual `BTRFS-{hash}` label. A backup is kept because FAT32 does not support `chattr +i`.

**Deploy main grub.cfg (immutable)**:
```python
cp ./GRUB_BTRFS/grub.cfg {mountpoint}/boot/grub2/grub.cfg
chattr +i {mountpoint}/boot/grub2/grub.cfg
```

**Disable GRUB script generators**:
```python
chmod -x {mountpoint}/etc/grub.d/*
```

See [DESIGN.md — GRUB Chain](../DESIGN.md#grub-chain-3-stage-bootloader).

### grub2-mkrelpath Wrapper Deployment

```python
mv {mountpoint}/usr/bin/grub2-mkrelpath {mountpoint}/usr/bin/grub2-mkrelpath-ORIGINAL

# Write wrapper script
echo '#!/usr/bin/bash
echo "/boot"$(/usr/bin/grub2-mkrelpath-ORIGINAL -r "$1")' > {mountpoint}/usr/bin/grub2-mkrelpath

chmod a+x {mountpoint}/usr/bin/grub2-mkrelpath
chattr +i {mountpoint}/usr/bin/grub2-mkrelpath
chattr +i {mountpoint}/usr/bin/grub2-mkrelpath-ORIGINAL
```

DNF exclusions are added to prevent package updates from overwriting the wrapper:

```python
echo 'exclude="grub2*"' >> {mountpoint}/etc/dnf/dnf.conf
# + /etc/dnf/protected.d/CUSTOM-grub2.conf protecting grub2-tools
```

See [DESIGN.md — grub2-mkrelpath Wrapper](../DESIGN.md#grub2-mkrelpath-wrapper-workaround).

### Kernel Cmdline

```python
echo "root=LABEL=BTRFS-{hash} rootflags=subvol=boot ro nowatchdog split_lock_detect=off zswap.enabled=0" > {mountpoint}/etc/kernel/cmdline
chattr +i {mountpoint}/etc/kernel/cmdline
```

This file controls what `kernel-install` puts into BLS entries. See [DESIGN.md — Kernel Parameters](../DESIGN.md#kernel-parameters).

### Kernel Reinstall for BLS Regeneration

```python
dnf reinstall kernel-core
```

This triggers `kernel-install`, which generates BLS entries using the now-deployed `grub2-mkrelpath` wrapper. The kernel was installed in Call 3 (before the wrapper existed), so its BLS entries had wrong paths. The reinstall regenerates them correctly.

`dnf reinstall kernel-core` is deliberately chosen over `kernel-install add` because it executes whatever the kernel package's current scriptlets do, even if they change across Fedora releases. A direct `kernel-install add` call would be a frozen assumption about internal implementation.

### Rescue Entry Fixup

The rescue BLS entry is generated by `51-dracut-rescue.install`, which does not use the `grub2-mkrelpath` wrapper:

```python
sed -i "s|^options .*|options $(cat {mountpoint}/etc/kernel/cmdline) |g" {mountpoint}/boot/loader/entries/*rescue.conf
sed -i "s| /root/boot/| /boot/boot/|g" {mountpoint}/boot/loader/entries/*rescue.conf
```

Fixes both the kernel cmdline options and the kernel/initramfs paths.

### DNF Update

```python
dnf update   # Update all packages to latest version
```

### SELinux Relabeling

Immutable bits must be temporarily removed because `setfiles` needs to write extended attributes:

```python
chattr -i {mountpoint}/boot/grub2/grub.cfg {mountpoint}/usr/bin/grub2-mkrelpath {mountpoint}/etc/kernel/cmdline

chroot {mountpoint} /bin/bash -c "setfiles -F /etc/selinux/targeted/contexts/files/file_contexts /"

chattr +i {mountpoint}/boot/grub2/grub.cfg {mountpoint}/usr/bin/grub2-mkrelpath {mountpoint}/etc/kernel/cmdline
```

The `setfiles` command may produce warnings (error code is ignored) -- some are expected during installroot.

### Final Steps

```python
echo "root:root" | chpasswd --root {mountpoint}/    # Set initial root password
cp -a ./../ {mountpoint}/root/fedora_from_scratch    # Copy repo into installed system
```

The initial root password is `root` -- intentional for the install workflow. Change it after setup or rely on the user account created in Phase 2.

The repo copy at `/root/fedora_from_scratch` is where Phase 2 runs from.

## Error Handling

`shell_cmd()` in `lib.py` wraps `subprocess.run()` with:

- **Command printing**: Every command is printed in bold before execution (audit trail)
- **Return code checking**: Non-zero exits terminate the script immediately unless `ignore_error_code=True`
- **Output modes**: Either real-time stdout passthrough (`print_stdout=True`, default) or captured for programmatic use
- **Stderr**: Always merged with stdout via `stderr=subprocess.STDOUT`

The entire session is tee'd to `os_installation.log` via `exec > >(tee "$install_log") 2>&1` in `autorun.sh`.
