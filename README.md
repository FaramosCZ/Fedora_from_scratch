# FEDORA_FROM_SCRATCH

Custom Fedora Linux installer that replaces Anaconda with a reproducible, scriptable, and heavily optimized installation process. Built by me - a Fedora developer and package maintainer - and maintained for a fleet of nearly 50 machines -- from 2007-era BIOS-only laptops with cheap SSD upgrades to modern UEFI gaming desktops and heavy-duty workstations. All machines run Fedora with the Cinnamon desktop environment.

The project started as a learning exercise to understand what it takes to install a GNU/Linux OS from scratch. It has since become the only installer I use, because it is easily customizable, maintainable, and produces consistently optimized systems that the default Fedora installer cannot match.

> **WARNING:** This project erases **ALL data** on the selected drive. There is no confirmation prompt beyond the configuration step. Make sure `os_installation/config.py` points at the correct disk before running.

## Hardware Requirements

| Requirement | Value | Notes |
|---|---|---|
| Architecture | x86_64 | Other architectures untested |
| CPU | 64-bit | 32-bit is dying, no motivation to support it |
| RAM | >= 2 GB | |
| Storage | SATA or NVMe SSD | HDD technically works but untested. A cheap SSD is the single best upgrade for old laptops |
| Firmware | UEFI (default) | BIOS-only machines supported via device-specific branches |
| Boot medium | Fedora Live USB | Does not need to fully match the target Fedora version (see [custom repo trick](DESIGN.md#dnf-installroot--custom-repo)) but match is much recommended, since I haven't tested e.g. using DNF 4 to install DNF 5 release etc. |

## Usage

1. Boot a [Fedora Live USB](https://fedoraproject.org/cs/spins/cinnamon/download/), switch to root.
2. Clone this repository. Check out the branch for your target device (`master` contains most stable, but not latest version).
3. Configure two files:
   - `os_installation/config.py` -- set target `disk` and desired `fedora_release`
   - `os_configuration/user_conf.sh` -- set `USER` and `USER_PRETTY`
4. **Phase 1 -- Install the OS.** Run `./autorun.sh` from the repo root. This installs a headless Fedora server onto the target disk. When finished, remove the USB and reboot into the new system.
5. **Phase 2 -- Configure the system.** Log in as root (password: `root`). Navigate to `/root/fedora_from_scratch/os_configuration/` and run `./autorun.sh`. This installs the Cinnamon desktop, configures the system, creates a user account, and reboots automatically.
6. **Phase 3 -- Restore user settings.** After rebooting into the GUI, open terminal, log in as root. Navigate to `/root/fedora_from_scratch/os_configuration/` and run `./200_restore_cinnamon_settings.sh` followed by `./300_make_final_btrfs_snapshot.sh`.

## The General Idea

Any OS installation consists of just a few fundamental steps:

1. **Prepare storage** -- partitioning, formatting, mounting
2. **Install the OS** -- install packages into a chroot (where the chroot is the prepared mount)
3. **Set up the bootloader** -- configure GRUB
4. **Configure the system** -- locale, users, software, desktop environment

The default Fedora installer (Anaconda) aims to be as universal as possible, supporting any hardware and any use case. This naturally conflicts with optimization for specific setups. This project takes the opposite approach: full control over every decision, tuned for a known fleet of machines.

## Three-Phase Architecture

| Phase | Directory | Language | What it does |
|---|---|---|---|
| 1 | `os_installation/` | Python | Partitions disk, creates BTRFS + EFI filesystems, installs packages via DNF installroot, sets up the GRUB bootloader chain, generates BLS boot entries |
| 2 | `os_configuration/0*.sh` | Bash | System-level configuration: hostname, locale, timezone, repositories, Cinnamon DE installation with bloat removal, software, user creation |
| 3 | `os_configuration/2*.sh`, `3*.sh` | Bash | User-level configuration: Cinnamon dconf settings, editor preferences, taskbar pinned apps, final BTRFS snapshot |

## Branch Strategy

Each machine (or class of machines) gets its own branch with device-specific configuration.

- **`master`** -- tracks the latest stable UEFI hardware configuration
- **`f44`**, **`f43`**, etc. -- Fedora-release-specific development branches
- **`HASH-NTB-*`** -- laptop branches (UEFI)
- **`HASH-BIOS-*`** -- laptop branches (BIOS-only, for old hardware)
- **`PC-gaming-*`** -- gaming desktop branches
- **Special branches** -- `HASH-luks` (LUKS encryption), `HASH-ryzen` (AMD tuning)

Branches may differ in `config.py` (disk device, Fedora release), kernel parameters, WiFi firmware packages, and BIOS vs UEFI bootloader setup. The goal is minimal code duplication -- most branches share the same scripts and only override device-specific configuration.

## Documentation

- **[DESIGN.md](DESIGN.md)** -- Technical design decisions and rationale (partitioning, BTRFS subvolumes, GRUB chain, kernel parameters, bootloader landscape)
- **[os_maintenance/README.md](os_maintenance/README.md)** -- Maintenance scripts and operations guide (snapshots, rollback, label fixups, BTRFS maintenance, GRUB updates)
- **[os_installation/README.md](os_installation/README.md)** -- Phase 1 step-by-step walkthrough
- **[os_configuration/README.md](os_configuration/README.md)** -- Phase 2 & 3 script-by-script reference
