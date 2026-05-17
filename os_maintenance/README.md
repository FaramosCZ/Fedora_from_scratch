# OS Maintenance

Standalone scripts for root. Run any script with `--help` or read the header comment for usage.

For design reasoning behind these procedures, see [DESIGN.md](../DESIGN.md).

## Procedures Not Covered by Scripts

### Creating Snapshots

```bash
mount --target /mnt/BTRFS-ROOT
cd /mnt/BTRFS-ROOT
btrfs subvolume snapshot -r boot RO-BACKUP-{name}
```

Always use `-r` (read-only). Snapshot before major changes: Fedora version upgrades, kernel updates, large package changes.

### Rolling Back to a Snapshot

Read-only snapshots cannot be booted directly. Create a read-write copy, then switch the boot symlink:

```bash
mount --target /mnt/BTRFS-ROOT
cd /mnt/BTRFS-ROOT
btrfs subvolume snapshot RO-BACKUP-01-minimal_headless_server_setup_finished rw-restored
unlink boot
ln -s rw-restored boot
reboot
```

No other changes needed — fstab, EFI grub.cfg, and BLS entries all resolve through the `boot` symlink.

### Deleting Snapshots

```bash
btrfs subvolume delete /mnt/BTRFS-ROOT/old-snapshot
```

### Fedora Version Upgrade

See [official docs](https://docs.fedoraproject.org/en-US/quick-docs/upgrading-fedora-offline/).

```bash
# 1. Update current system first
dnf upgrade --refresh

# 2. Snapshot before upgrade
mount --target /mnt/BTRFS-ROOT
cd /mnt/BTRFS-ROOT
btrfs subvolume snapshot -r boot RO-BACKUP-before-f{XX}-upgrade

# 3. Download packages for the new release
dnf system-upgrade download --releasever={XX}

# 4. Reboot into the offline upgrade
dnf system-upgrade reboot       # DNF 4 (Fedora 40 and older)
dnf offline reboot              # DNF 5 (Fedora 41+)

# 5. After upgrade completes, update again to catch any post-upgrade fixes
dnf upgrade --refresh

# 6. Snapshot the upgraded system
mount --target /mnt/BTRFS-ROOT
cd /mnt/BTRFS-ROOT
btrfs subvolume snapshot -r boot RO-BACKUP-after-f{XX}-upgrade
```

If the upgrade breaks something, roll back to the pre-upgrade snapshot (see Rolling Back above).

### Defragment and TRIM

Not scripted because they are rarely needed and have nuances worth reading `man btrfs-filesystem` for:

```bash
btrfs filesystem defragment -r -v /
fstrim -v /
```

Fedora enables weekly `fstrim.timer` by default. Defrag is mainly useful after enabling compression to recompress existing files.

### GRUB Update Procedure

GRUB packages are excluded from `dnf update` via `exclude="grub2*"` in `/etc/dnf/dnf.conf`. For critical security updates:

1. `chattr -i` on all four protected files (see `list_protected_files.sh`)
2. Remove `exclude="grub2*"` from `/etc/dnf/dnf.conf`
3. Run the GRUB update
4. Verify the `grub2-mkrelpath` wrapper is still in place
5. Verify `/boot/grub2/grub.cfg` was not overwritten (restore from `GRUB_BTRFS/grub.cfg` in the repo if needed)
6. Verify BLS entries still have correct paths (`/boot/boot/...` not `/root/boot/...`)
7. Re-apply `chattr +i` on all four files
8. Re-add `exclude="grub2*"` to `/etc/dnf/dnf.conf`

## Caveats

### btrfs send/receive Does Not Preserve Immutable Bits

After receiving a snapshot on a new device, re-apply:

```bash
chattr +i /boot/grub2/grub.cfg /etc/kernel/cmdline /usr/bin/grub2-mkrelpath /usr/bin/grub2-mkrelpath-ORIGINAL
```

See [btrfs-progs issue #1057](https://github.com/kdave/btrfs-progs/issues/1057).

### DNF Exclusions

Two mechanisms silently affect package management:

| Mechanism | Location | Effect |
|---|---|---|
| `exclude="grub2*"` | `/etc/dnf/dnf.conf` | All GRUB packages skipped during updates |
| `grub2-tools` | `/etc/dnf/protected.d/CUSTOM-grub2.conf` | `grub2-tools` cannot be removed by dependency resolution |

`dnf update` will not mention skipped packages unless you check with `--disableexcludes=all`.

### /home Portability

Copying `/home` from an old installation to a new one works seamlessly if the same software is installed on both — you stay logged into your apps, browser state is preserved.

Over time, `/home` silently grows with remnants of uninstalled applications scattered across `~/.config/`, `~/.local/share/`, `~/.cache/`, and application-specific dotfiles. Accept the bloat or do a fresh start with selective data migration.
