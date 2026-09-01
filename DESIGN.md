# Design Decisions

This document records the reasoning behind every significant technical choice in the project. It is written for my future self and for anyone inheriting the project. For implementation details, see [os_installation/README.md](os_installation/README.md) and [os_configuration/README.md](os_configuration/README.md).

## Partitioning & Filesystem

### GPT for Everything

GPT is used on all machines, including BIOS-only ones. No target hardware requires MBR -- all machines in the fleet are x86_64 (64-bit, 2007+) and support GPT. GRUB2 handles GPT on BIOS systems via a BIOS boot partition (on BIOS branches) or a standard EFI partition (on UEFI branches).

### Minimal Partition Count

Only two partitions:

| Partition | Size | Type | Filesystem |
|---|---|---|---|
| 1 (EFI) | 500 MB | `C12A7328-F81F-11D2-BA4B-00A0C93EC93B` | FAT32 |
| 2 (System) | Rest of disk | Default | BTRFS |

No swap partition -- modern Fedora uses zram (compressed RAM swap) by default.

The EFI partition is oversized for GRUB alone (~2 MB needed), but 500 MB accommodates fwupd firmware update capsules which can require tens of MB each.

### BTRFS as the Sole Filesystem

BTRFS was chosen for its native subvolume and snapshot support, which eliminates the need for LVM. A single BTRFS partition holds everything: the OS, `/boot`, `/home`. Snapshots are atomic, nearly free in space, and enable the rollback mechanism described below.

### Flat Subvolume Layout

All subvolumes and snapshots sit directly under the BTRFS root (ID 5), not nested inside each other. This makes `btrfs send/receive` to other devices straightforward and snapshot management simple -- `ls` the BTRFS root to see everything.

### Single OS Subvolume

One `root` subvolume contains the complete OS tree including `/boot` and `/home`. This is the simplest layout and works best for single-purpose machines (most of the fleet).

For multi-purpose setups (e.g., a machine with a large game library), directories like `~/Downloads` or `~/Games` can be split into separate subvolumes with their own fstab entries. I don't split `/home` out -- user configuration should travel with the OS snapshot for rollbacks to make sense.

## Label Naming Convention

### Random Hash Suffix

Filesystem labels use a random 6-character uppercase alphanumeric suffix generated at install time:

- `EFI-A3X9K2` -- FAT32 on the EFI partition
- `BTRFS-A3X9K2` -- BTRFS on the system partition

The hash prevents label collisions when multiple installations exist on different disks, or when the live USB itself has labeled partitions.

### Why 6 Characters, Uppercase

FAT32 volume labels are limited to **11 characters**. The `EFI-` prefix (4 chars) + 6 hash chars = 10, fitting within the limit.

BTRFS allows 255-character labels, but the `BTRFS-` prefix (6 chars) + 6 hash chars = 12 is kept consistent with EFI for simplicity and admin-friendliness.

Uppercase letters avoid warnings on old firmware that expects FAT labels in uppercase (FAT stores labels uppercase internally).

### Labels Instead of UUIDs

Every mount reference (fstab, kernel cmdline, BLS boot entries, GRUB config) uses `LABEL=` instead of `UUID=` or hardcoded device paths like `/dev/sda1`. Labels are:

- **Human-readable** -- you can tell which partition belongs to which install at a glance
- **Portable** -- survive controller reassignments and disk moves between machines
- **Unique enough** -- the random hash prevents collisions in practice

## BTRFS Subvolume & Boot Symlink Design

### The `root` Subvolume

Created at the BTRFS root level during installation:

```
btrfs subvolume create /mnt/FEDORA_FROM_SCRATCH/root
```

Contains the complete OS filesystem tree.

### The `boot` Symlink

A symlink at the BTRFS root level points to the active subvolume:

```
ln -s "root" "boot"
```

All mount operations use `subvol=boot` -- they go through the symlink. GRUB resolves BTRFS symlinks correctly, so the entire boot chain references `boot` without knowing (or caring) which subvolume it actually points to.

### Rollback Mechanism

To roll back to a previous state:

1. Mount the BTRFS root (`mount --target=/mnt/BTRFS-ROOT`)
2. Create a read-write snapshot of the desired read-only backup
3. Change the symlink: `unlink boot && ln -s <snapshot-name> boot`
4. Reboot

No BLS entry editing, no fstab changes, no EFI partition changes. The symlink is the single point of control.

### Convenience Mount

The fstab includes a `noauto` entry for `/mnt/BTRFS-ROOT` that mounts the BTRFS root (`subvol=/`). Used by snapshot scripts and for manual maintenance:

```
LABEL=BTRFS-{hash}  /mnt/BTRFS-ROOT  btrfs  noatime,subvol=/,X-mount.mkdir,noauto  0  0
```

## Automatic DNF Snapshots

Every DNF5 transaction (install, update, remove) automatically creates a read-only Btrfs snapshot before making changes. This covers both manual `dnf` and `dnf-automatic`.

### Mechanism

`libdnf5-plugin-actions` reads `.actions` files from `/etc/dnf/libdnf5-plugins/actions.d/`. A one-line actions file triggers a script on `pre_transaction`. The script mounts the Btrfs root (if not already mounted), snapshots the active subvolume through the `boot` symlink, and prunes old auto-snapshots beyond the retention limit.

### Why Not Snapper or Timeshift

Both are designed for general-purpose snapshot management with their own metadata, configuration, and cleanup policies. This project already has a simple snapshot convention (`RO-BACKUP-*` at the Btrfs root level, `boot` symlink for rollback). A raw `btrfs subvolume snapshot` call fits the existing design without adding a new abstraction layer or daemon.

### Design Choices

| Choice | Rationale |
|---|---|
| Snapshots through `boot` symlink | Always snapshots whichever subvolume is currently active, even after a rollback |
| Read-only (`-r`) | Immutable, consistent with the project's existing snapshot convention |
| 10 auto-snapshot retention | Generous for workstations; Btrfs CoW deduplication means incremental snapshots are cheap |
| `RO-BACKUP-auto-*` prefix | Distinguishes automatic snapshots from manual `RO-BACKUP-NN-*` ones; only auto-snapshots are pruned |
| Script in `/usr/local/bin/` | Survives package updates, standard local scripts location |

### Rollback From an Auto-Snapshot

Same procedure as any other snapshot — change the `boot` symlink and reboot. See [os_maintenance/README.md — Rolling Back](os_maintenance/README.md#rolling-back-to-a-snapshot). For a permanent rollback, create a read-write copy from the read-only auto-snapshot first.

## GRUB Chain (3-Stage Bootloader)

### Stage 1: EFI Firmware to GRUB

EFI firmware loads shim (for Secure Boot), shim loads the GRUB EFI binary. GRUB reads its first configuration from the EFI partition.

### Stage 2: EFI grub.cfg (Trampoline)

Located at `/boot/efi/EFI/fedora/grub.cfg` on the FAT32 EFI partition. This is a minimal trampoline:

```
insmod part_gpt
insmod btrfs
btrfs_subvolume=boot
search --no-floppy --set=root --label BTRFS-{hash}
configfile ($root)/$btrfs_subvolume/boot/grub2/grub.cfg
```

It loads the BTRFS module, finds the BTRFS partition by label, and chains into the real grub.cfg on the BTRFS subvolume. The key variable is `btrfs_subvolume=boot` -- this is the symlink name, not a subvolume name.

This file is static. It never needs changing, regardless of which subvolume the `boot` symlink points to. A backup copy (`grub.cfg-BACKUP`) is kept on the EFI partition because FAT32 does not support `chattr +i`.

### Stage 3: Main grub.cfg (Immutable)

Located at `/boot/grub2/grub.cfg` on the BTRFS subvolume. Protected with `chattr +i`.

```
insmod blscfg
blscfg "($root)/$btrfs_subvolume/boot/loader/entries"
menuentry "Enter BIOS" { fwsetup }
menuentry "Power off" { halt }
```

Loads BLS entries dynamically, adds convenience menu items. This config lives on BTRFS, so it gets snapshotted together with the OS.

### BLS (Boot Loader Specification)

Kernel boot entries are drop-in `.conf` files in `/boot/loader/entries/`. Generated by `kernel-install` when a kernel package is installed. Each entry references the kernel, initramfs, and kernel cmdline options. Paths in BLS entries go through the `boot` symlink (thanks to the [grub2-mkrelpath wrapper](#grub2-mkrelpath-wrapper-workaround)).

### /etc/default/grub

```
GRUB_TIMEOUT=1
GRUB_DISABLE_UUID=true
GRUB_ENABLE_BLSCFG=true
```

One-second timeout, labels instead of UUIDs, BLS mode enabled.

### GRUB Script Disabling

All scripts in `/etc/grub.d/` are made non-executable (`chmod -x`). This prevents `grub2-mkconfig` from regenerating the configuration and overwriting the custom immutable grub.cfg.

## grub2-mkrelpath Wrapper Workaround

### The Problem

When the `kernel-core` package is installed or updated, `kernel-install` triggers BLS entry generation. The script `20-grub.install` (from `grub2-common`) calls `grub2-mkrelpath` to determine kernel/initramfs paths from GRUB's perspective.

`grub2-mkrelpath` resolves the actual BTRFS subvolume name (`root`), producing paths like `/root/boot/vmlinuz-...`. But the boot chain uses the `boot` symlink, expecting `/boot/boot/vmlinuz-...`. The direct subvolume path works for booting but **breaks rollback** -- it hardcodes the subvolume name instead of going through the symlink.

### Two BLS Generators

Two independent scripts generate BLS entries:

| Script | Package | Calls grub2-mkrelpath? | Result |
|---|---|---|---|
| `20-grub.install` | grub2-common | **Yes** | Wrong path (`/root/boot/...`) |
| `90-loaderentry.install` | systemd | No | Correct path, but `20-grub.install` runs first |

### The Wrapper

The original binary is renamed to `grub2-mkrelpath-ORIGINAL`. A wrapper script takes its place:

```bash
#!/usr/bin/bash
echo "/boot"$(/usr/bin/grub2-mkrelpath-ORIGINAL -r "$1")
```

This forces all paths through the `boot` symlink, producing `/boot/boot/vmlinuz-...` regardless of the actual subvolume name.

### Protection Layers

The wrapper is protected by multiple independent mechanisms:

| Protection | What it prevents |
|---|---|
| `chattr +i` on wrapper and original binary | Any process from modifying or deleting them |
| `exclude="grub2*"` in `/etc/dnf/dnf.conf` | DNF from even attempting GRUB package updates |
| `grub2-tools` in `/etc/dnf/protected.d/CUSTOM-grub2.conf` | DNF from removing grub2-tools during dependency resolution |
| `chmod -x /etc/grub.d/*` | `grub2-mkconfig` from regenerating configuration |

Belt-and-suspenders: any single layer failing does not break the system.

### Rescue Entry Fixup

The rescue BLS entry (`*rescue.conf`) is generated by `51-dracut-rescue.install`, which does not honor the `grub2-mkrelpath` wrapper. Manual `sed` fixup is applied after kernel reinstall:

```bash
sed -i "s|^options .*|options $(cat /etc/kernel/cmdline) |g" /boot/loader/entries/*rescue.conf
sed -i "s| /root/boot/| /boot/boot/|g" /boot/loader/entries/*rescue.conf
```

### Alternatives Evaluated

| Approach | Verdict |
|---|---|
| `SUSE_BTRFS_SNAPSHOT_BOOTING=true` | **Tested, makes it worse.** The `-r` flag strips too much, producing an incorrect path (`/boot/vmlinuz-...` instead of `/boot/boot/vmlinuz-...`). Designed for openSUSE's different GRUB setup. |
| Disable `20-grub.install`, rely on `90-loaderentry.install` only | Risky -- may lose GRUB-specific features |
| Custom kernel-install plugin (post-fixup) | More moving parts for the same result |
| Upstream fix to `grub2-mkrelpath` | The correct long-term solution. This is a genuine bug -- `grub2-mkrelpath` does not handle subvolume symlinks. |

## DNF Installroot & Custom Repo

### The Version Decoupling Problem

The live USB may run a different Fedora version than the target installation (e.g., live USB is F43, target is F44). DNF's `--installroot` defaults to using the host system's repos, which would install the wrong version.

### The Custom Repo Solution

A temporary repo file is created on the live system with metalink URLs pointing at the target Fedora release:

```ini
[fedora-custom]
name=fedora-custom
enabled=0
gpgcheck=0
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-44&arch=$basearch
```

The first DNF call uses `--use-host-config` with these custom repos explicitly enabled. This installs `@core` which includes the `fedora-release` package, populating the installroot's own `/etc/yum.repos.d/`. All subsequent DNF calls use the installroot's repos naturally.

### Version decoupling issues

I **strongly recommend** that host Fedora version and installed Fedora version match.

In theory the custom repo solution works for any combination. In practice major Fedora Changes can break it - especially changes to DNF (DNF 4 -> 5 change, change of DNF compression algorithm, ...).

It isn't worth the trouble :)

### Why --nogpgcheck

GPG keys are not available in the installroot during the first DNF call (they come from the `fedora-release` package being installed). The risk is low: packages come from official Fedora mirrors via metalink, which includes checksum verification.

Potenital area for improvement.

## Kernel Parameters

### Adopted (All Branches)

Added to `/etc/kernel/cmdline` alongside `root=LABEL=... rootflags=subvol=boot ro`:

| Parameter | Effect | Rationale |
|---|---|---|
| `nowatchdog` | Disables soft lockup + NMI hard lockup detectors from early boot | Frees a PMU counter per CPU, eliminates NMI overhead, enables deeper CPU sleep states on laptops. No downside for desktop use. Boot parameter preferred over sysctl to cover early boot and disable both detectors. |
| `split_lock_detect=off` | Disables the kernel's 10ms penalty for unaligned atomic operations | Games under Proton/Wine trigger split locks constantly, causing stuttering. CachyOS disables this by default. Harmless on AMD and older Intel. |
| `zswap.enabled=0` | Explicitly disables zswap | Modern Fedora uses zram; zswap would cause double-compression. Currently off in kernel config but this protects against future `CONFIG_ZSWAP_DEFAULT_ON` changes. |

### Rejected

| Parameter | Why rejected |
|---|---|
| `mitigations=off` | AMD Zen 4 CPUs benchmark ~3% **faster** with mitigations ON (speculative execution changes, per Phoronix). Old Intel gains modest speed but browser JS exploits are a real risk. Fleet is mixed AMD/Intel. |
| `preempt=full` | Fedora 44 / kernel 7.0 defaults to `PREEMPT_LAZY` (replaced `voluntary`). Good enough for desktop + gaming. Full preempt only matters for audio production. |
| `pcie_aspm=force` | Kernel docs warn "may cause system lockups." Old NVIDIA GPUs and WiFi cards can hang. Too risky for mixed fleet. |
| `workqueue.power_efficient=1` | Hurts desktop performance (cache misses), reports of constant idle SSD writes. |
| `nohz_full=all` | For HPC, not desktop. Increases scheduling overhead with many interactive apps. |
| `threadirqs` | Too specialized for audio production. Adds overhead for general desktop. |
| `elevator=` | Too blunt for mixed storage. NVMe uses `none`, SATA uses `mq-deadline` -- both correct defaults already. |
| THP changes | Fedora already defaults to `madvise` -- optimal desktop setting. |

### Laptop-Only Candidates (Not Yet Applied)

These are candidates for laptop-specific branches only, not applied fleet-wide:

| Parameter | Effect | Why not universal |
|---|---|---|
| `rcu_nocbs=all rcutree.enable_rcu_lazy=1` | Batches RCU callbacks, reduces CPU wakeups. CachyOS reports 5-10% power savings. | Added memory reclamation latency not worth it on wall-powered desktops. |
| `processor.ignore_ppc=1` | Overrides BIOS CPU frequency caps. Some old ThinkPads/Dells have BIOS bugs locking CPU at minimum frequency. | Only affects machines with buggy BIOS `_PPC`. Risk of overdrawing weak AC adapters. |

## Immutable File Protections

### Protected Files

| File | Why protected |
|---|---|
| `/boot/grub2/grub.cfg` | Prevents `grub2-mkconfig` or package updates from overwriting custom GRUB config. Still GRUB is excluded from DNF updates so it won't change the grub.cfg on the EFI partition, that can't be protected otherwise|
| `/etc/kernel/cmdline` | Prevents `kernel-install` from resetting kernel parameters. Note: don't forget to update this file when you want permanently change kernel parameters (e.g. GPU swich between AMD and NVidia in gaming PC), otherwise the net kernel update won't get them. |
| `/usr/bin/grub2-mkrelpath` | Protects the wrapper script |
| `/usr/bin/grub2-mkrelpath-ORIGINAL` | Protects the original binary (needed by the wrapper) |

### SELinux Relabeling

`setfiles` needs to write extended attributes on all files. The immutable bit prevents this, so `chattr -i` is applied temporarily on all four files before SELinux relabeling, and `chattr +i` is restored immediately after.

### Complementary Protections

- **DNF exclude** (`dnf.conf`): `exclude="grub2*"` prevents package updates from even downloading
- **DNF protected.d**: `grub2-tools` cannot be removed during dependency resolution
- **GRUB script disabling**: `chmod -x /etc/grub.d/*` prevents config regeneration
- **EFI backup**: `grub.cfg-BACKUP` on EFI partition (FAT32 does not support `chattr +i`)

## BTRFS Mount Options

### Applied

| Option | Why |
|---|---|
| `noatime` | Critical for BTRFS with snapshots. Without it, every file read updates access time metadata, which triggers copy-on-write of metadata blocks. With snapshots, this inflates snapshot sizes significantly. `noatime` eliminates this overhead entirely. |
| `subvol=boot` | Mounts through the symlink (see [Subvolume & Boot Symlink Design](#btrfs-subvolume--boot-symlink-design)). |

### Evaluated and Skipped

| Option | Status | Reasoning |
|---|---|---|
| `ssd` | Skip | Auto-detected by BTRFS kernel module since kernel 2.6.29 from `/sys/block/DEV/queue/rotational`. Explicitly setting it is harmless but unnecessary. |
| `discard=async` | Skip | Default since kernel 6.2. Freed extents are batched and trimmed by a background thread. Unnecessary to set explicitly on Fedora 44+. |
| `space_cache=v2` | Skip | Free-space tree. Default since `mkfs.btrfs` 5.15. Created at filesystem creation time. |
| `autodefrag` | Skip | Detects small random writes and redefragments in background. On SSDs: no seek time penalty from fragmentation, so benefit is marginal. Causes extra writes (SSD wear). Interacts badly with snapshots and large files. |

### Pending Benchmarks

| Option | Concern | Status |
|---|---|---|
| `compress=zstd` | The fleet's old laptops are **CPU-bound**, not I/O-bound. Even `zstd:1` (~384 MB/s compress) adds CPU overhead on every read and write. On CPU-constrained machines, compression could make the system slower despite reduced I/O. | Blocked on real benchmarks on representative target hardware |
| `commit=N` | Extends dirty data flush interval from 30s default. Higher values (e.g., 120s) reduce writes but increase data loss window on crash. Old laptops on battery are crash-prone (battery death). | Risk/benefit tradeoff varies per device class |
| `ssd_spread` | Allocates into bigger aligned chunks. Meant for low-end SSDs with poor FTL. May help old/cheap SSDs but could cause over-allocation on modern drives. | Hard to evaluate without testing on actual target hardware |

The key insight is that theoretical recommendations fail when the fleet spans from weak-CPU old laptops to fast-CPU gaming PCs. Decisions on CPU-impacting options (especially compression) require real benchmarks on real hardware.

## Bootloader Landscape (Why GRUB2)

### Requirements

The bootloader must support:

1. **BIOS boot** -- the fleet includes BIOS-only laptops (2007-era)
2. **UEFI boot** -- modern machines
3. **Native BTRFS** -- reading kernels, initramfs, and configs directly from BTRFS subvolumes, snapshotted together with the OS

### GRUB2 Is the Only Option

| Bootloader | BTRFS driver | UEFI | BIOS | Verdict |
|---|---|---|---|---|
| **GRUB2** | Yes (native) | Yes | Yes | **The only option meeting all requirements** |
| systemd-boot | No (FAT32 only) | Yes | No | Kills BIOS branches, requires copying kernels to ESP |
| rEFInd | Yes (built-in) | Yes | No | No BIOS support |
| Limine | No | Yes | Yes (limited) | No BTRFS, requires 4GB+ ESP for snapshot kernels |
| UKI | No (lives on ESP) | Yes | No | Kernel packaging format, not a bootloader |
| EFISTUB | No | Yes | No | No BTRFS, no menu, no snapshot booting |

Alternatives that lack BTRFS support would require copying kernels from BTRFS to the ESP (FAT32), which means snapshots no longer include kernels. This creates a kernel/module version mismatch risk and requires extra tooling.

### Industry Direction

openSUSE Tumbleweed moved from GRUB2 to GRUB2-BLS (Nov 2025) to systemd-boot (Apr 2026) in 6 months. Fedora is more conservative -- heading the same direction with bootupd, UKI, and mkosi-initrd, but GRUB2 remains the default. GRUB2 will not disappear anytime soon; it is the only option for BIOS and the only one with native BTRFS.

## Cinnamon DE Optimization

### Bloat Removal (~490 MiB Saved)

The `cinnamon-desktop` DNF group pulls in many packages not needed for this fleet. Two `dnf remove` calls strip them:

**Phase 1 -- Applications and heavy dependencies:**
dnfdragora, pidgin, xfburn, thunderbird, xawtv, shotwell, ImageMagick, anaconda components, trousers, yelp, redshift, mpv, gnome-calculator, gnome-calendar, plymouth, fwupd, PackageKit, deltarpm, enchant, exiv2, fortune-mod, geolite, hexchat, kpartx, nilfs-utils, onboard, pcsc-lite, evolution

**Phase 2 -- CJK input methods, accessibility, unused data:**
ibus-anthy, ibus-chewing, ibus-hangul, ibus-libpinyin, ibus-m17n, ibus-typing-booster (fleet uses only en_US and cs_CZ), speech-dispatcher, espeak-ng, flite, paper-icon-theme, libmateweather-data, unicode-ucd, cldr-emoji-annotation

### Hard Dependencies That Should Be Recommends

Six packages cannot be removed because Cinnamon (or cinnamon-screensaver) hard-depends on them, even though the DE functions correctly without them. Per Fedora packaging guidelines, these should be `Recommends`, not `Requires`:

| Package | Size | Used for | DE works without? |
|---|---|---|---|
| caribou | 617 KiB + deps | On-screen keyboard (unmaintained, archived upstream) | Yes |
| gucharmap | ~8 MiB | One context menu item in keyboard applet | Yes |
| gnome-backgrounds | 38 MiB | Extra wallpaper choices (default wallpaper comes from desktop-backgrounds-basic) | Yes |
| cinnamon-translations | 25 MiB | Localized UI strings (gettext falls back to English gracefully) | Yes |
| cups-client | ~180 KiB | Printer settings panel | Yes |
| wget | ~3 MiB | Remote album art download in sound applet | Yes |

These are upstream bug report candidates for both Fedora Bugzilla (packaging) and Linux Mint GitHub (caribou migration, wget replacement with native GIO/libsoup).
