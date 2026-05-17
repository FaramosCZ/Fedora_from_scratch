# Maintenance Guide

Operations and maintenance procedures for systems installed by this project. For the design reasoning behind these procedures, see [DESIGN.md](DESIGN.md).

## Snapshot Management

### Creating Snapshots

Mount the BTRFS root subvolume using the prepared fstab entry, then create a read-only snapshot:

```bash
mount --target /mnt/BTRFS-ROOT
cd /mnt/BTRFS-ROOT
btrfs subvolume snapshot -r boot RO-BACKUP-{name}
```

The `boot` symlink is used as the source so the snapshot captures whichever subvolume is currently active.

Best practices:
- Always create read-only snapshots (`-r` flag) for backups
- Snapshot before major changes: Fedora version upgrades, kernel updates, large package changes
- The installer creates two snapshots automatically: `RO-BACKUP-01-minimal_headless_server_setup_finished` and `RO-BACKUP-02-GUI_setup_finished`

### Listing Snapshots

```bash
mount --target /mnt/BTRFS-ROOT
ls -la /mnt/BTRFS-ROOT/
btrfs subvolume list /mnt/BTRFS-ROOT
```

The flat layout means all subvolumes and snapshots are visible at the BTRFS root level.

### Rolling Back to a Snapshot

Read-only snapshots cannot be booted directly. Create a read-write copy, then switch the boot symlink:

```bash
mount --target /mnt/BTRFS-ROOT
cd /mnt/BTRFS-ROOT

# Create a writable copy of the backup
btrfs subvolume snapshot RO-BACKUP-01-minimal_headless_server_setup_finished rw-restored-subvolume

# Point the boot symlink to it
unlink boot
ln -s rw-restored-subvolume boot

reboot
```

No other changes needed. The fstab uses `subvol=boot`, the EFI grub.cfg uses the `boot` symlink, and BLS entries use paths that go through the symlink. Everything resolves to the new subvolume automatically.

### Deleting Old Snapshots

```bash
mount --target /mnt/BTRFS-ROOT
btrfs subvolume delete /mnt/BTRFS-ROOT/old-snapshot
```

Space is reclaimed asynchronously by BTRFS.

## The Boot Symlink Rollback Mechanism

The boot chain resolves paths through the `boot` symlink at the BTRFS root level:

```
EFI grub.cfg
  → search by label → finds BTRFS partition
  → configfile ($root)/boot/boot/grub2/grub.cfg
                       ^^^^
                       symlink → actual subvolume

Main grub.cfg
  → blscfg ($root)/boot/boot/loader/entries
                   ^^^^
                   same symlink
```

The `boot` in these paths is the symlink, not a directory. It resolves to whichever subvolume the symlink points to. Changing the symlink target is the only step needed to boot a different subvolume.

## Label Hash Locations

The random 6-character hash (e.g., `A3X9K2`) from the installation appears in four places:

| File | Content |
|---|---|
| `/boot/loader/entries/*.conf` | `options root=LABEL=BTRFS-{hash} rootflags=subvol=boot ...` |
| `/etc/fstab` | `LABEL=EFI-{hash}` and `LABEL=BTRFS-{hash}` |
| `/etc/kernel/cmdline` | `root=LABEL=BTRFS-{hash} rootflags=subvol=boot ...` |
| `/boot/efi/EFI/fedora/grub.cfg` | `search --no-floppy --set=root --label BTRFS-{hash}` |

### Fixing Labels After Cross-Device Snapshot Transfer

When using `btrfs send/receive` to move a snapshot to a machine with a different hash, update all four locations. The kernel cmdline and grub.cfg are protected by immutable bits -- remove them first:

```bash
# Remove immutable bits
chattr -i /boot/grub2/grub.cfg /etc/kernel/cmdline

# Replace old hash with new hash
OLD=OLDHASH
NEW=NEWHASH
sed -i "s/$OLD/$NEW/g" /etc/fstab
sed -i "s/$OLD/$NEW/g" /etc/kernel/cmdline
sed -i "s/$OLD/$NEW/g" /boot/loader/entries/*.conf
sed -i "s/$OLD/$NEW/g" /boot/efi/EFI/fedora/grub.cfg{,-BACKUP}

# Restore immutable bits
chattr +i /boot/grub2/grub.cfg /etc/kernel/cmdline
```

## Immutable Files

### What They Are

Four files are protected with the immutable bit (`chattr +i`):

```
/boot/grub2/grub.cfg
/etc/kernel/cmdline
/usr/bin/grub2-mkrelpath
/usr/bin/grub2-mkrelpath-ORIGINAL
```

Check their current state:

```bash
lsattr /boot/grub2/grub.cfg /etc/kernel/cmdline /usr/bin/grub2-mkrelpath /usr/bin/grub2-mkrelpath-ORIGINAL
```

### When to Temporarily Remove Protection

- **SELinux relabeling** (already handled by install scripts, but needed if doing manual relabeling)
- **Manual GRUB config changes** (rare -- only when debugging boot issues)
- **Label hash fixup** after cross-device snapshot transfer

```bash
chattr -i /path/to/file     # remove
# ... do the work ...
chattr +i /path/to/file     # restore
```

### btrfs send/receive Caveat

`btrfs send/receive` does **not** preserve extended attributes including the immutable bit (see [btrfs-progs issue #1057](https://github.com/kdave/btrfs-progs/issues/1057)). After receiving a snapshot on a new device, re-apply:

```bash
chattr +i /boot/grub2/grub.cfg /etc/kernel/cmdline /usr/bin/grub2-mkrelpath /usr/bin/grub2-mkrelpath-ORIGINAL
```

## BTRFS Filesystem Maintenance

Optional maintenance for heavily used systems over months or years:

```bash
# Rebalance data and metadata chunks
# Useful after heavy deletion/creation cycles
btrfs balance start -dusage=75 -musage=75 /

# Defragment files (useful after enabling compression to recompress existing files)
btrfs filesystem defragment -r -v /

# Send TRIM commands to SSD
# Fedora enables weekly fstrim.timer by default; manual run for one-off cleanup
fstrim -v /
```

Consult manual pages before running. Run these from a mounted filesystem, not from within a snapshot.

## System Cleanup Philosophy

Fedora releases a new version roughly every 6 months, with ~13 months of support per release. The `dnf system-upgrade` process works well and many installations last a decade through successive upgrades.

However, I prefer periodic clean reinstalls every few Fedora releases for several reasons:

- **Configuration drift**: DNF tries to honor user modifications to config files while upgrading defaults that were left untouched. In practice, not all default configurations can be safely upgraded, so fresh installs pick up the latest defaults.
- **This project makes reinstalls trivial**: clone, configure, run -- done in about 30 minutes on NVMe.
- **I keep enhancing these scripts**: reinstalls are how my fleet picks up improvements.

### /home Portability

Copying the full old `/home` directory from an old installation to a new one works seamlessly, provided the same software is installed on both. You stay logged into your apps, browser state is preserved, etc. -- all user configuration lives in `/home`.

### /home Bloat

Over time, `/home` silently grows with remnants of uninstalled applications. Data is scattered across `~/.config/`, `~/.local/share/`, `~/.cache/`, and application-specific dotfiles. Restoring from a clean `/home` is difficult because you need to know which data to transfer for each application. Accept the bloat or do a fresh start with selective data migration.

## GRUB Update Handling

GRUB packages are excluded from automatic updates via `exclude="grub2*"` in `/etc/dnf/dnf.conf`. This means `dnf update` silently skips all GRUB packages.

If a critical GRUB security update is needed, the manual procedure is:

1. `chattr -i` on all four protected files
2. Temporarily remove `exclude="grub2*"` from `/etc/dnf/dnf.conf`
3. Run the GRUB update
4. Verify the `grub2-mkrelpath` wrapper is still in place (package update may overwrite it)
5. Verify `/boot/grub2/grub.cfg` was not overwritten (restore from `GRUB_BTRFS/grub.cfg` in the repo if needed)
6. Verify BLS entries still have correct paths (`/boot/boot/...` not `/root/boot/...`)
7. Re-apply `chattr +i` on all four files
8. Re-add `exclude="grub2*"` to `/etc/dnf/dnf.conf`

This manual review is intentional -- GRUB updates can break both the wrapper and the custom configuration.

## DNF Exclusion Awareness

Two DNF mechanisms silently affect package management:

| Mechanism | Location | Effect |
|---|---|---|
| `exclude="grub2*"` | `/etc/dnf/dnf.conf` | All GRUB packages skipped during updates |
| `grub2-tools` | `/etc/dnf/protected.d/CUSTOM-grub2.conf` | `grub2-tools` cannot be removed during dependency resolution |

`dnf update` will not mention skipped packages unless you check with `--disableexcludes=all`. When troubleshooting "why doesn't GRUB update" -- check these two places first.
