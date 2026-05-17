#!/bin/bash

#----------------------------------------
# Change the partition label hash across all config files and disk labels
#
# Usage: ./hash_change.sh NEW_HASH

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Must be run as root" >&2
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 NEW_HASH" >&2
    echo "Example: $0 B7Y1M4" >&2
    exit 1
fi

NEW="$1"

if [[ ! "$NEW" =~ ^[A-Z0-9]{6}$ ]]; then
    echo "ERROR: NEW_HASH must be exactly 6 uppercase alphanumeric characters: $NEW" >&2
    exit 1
fi

OLD=$(grep -oP 'BTRFS-\K[A-Z0-9]{6}' /etc/fstab | head -1)

if [[ -z "$OLD" ]]; then
    echo "ERROR: Could not detect current hash from /etc/fstab" >&2
    exit 1
fi

if [[ "$OLD" == "$NEW" ]]; then
    echo "Current hash is already $OLD, nothing to do."
    exit 0
fi

echo "Changing hash: $OLD -> $NEW"
echo ""

# Remove immutable bits
echo "Removing immutable bits..."
chattr -i /boot/grub2/grub.cfg /etc/kernel/cmdline

# Config files
echo "Updating /etc/fstab"
sed -i "s/$OLD/$NEW/g" /etc/fstab

echo "Updating /etc/kernel/cmdline"
sed -i "s/$OLD/$NEW/g" /etc/kernel/cmdline

echo "Updating /boot/loader/entries/*.conf"
sed -i "s/$OLD/$NEW/g" /boot/loader/entries/*.conf

echo "Updating /boot/efi/EFI/fedora/grub.cfg and backup"
sed -i "s/$OLD/$NEW/g" /boot/efi/EFI/fedora/grub.cfg
sed -i "s/$OLD/$NEW/g" /boot/efi/EFI/fedora/grub.cfg-BACKUP

# Disk labels
BTRFS_DEV=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
EFI_DEV=$(findmnt -n -o SOURCE /boot/efi)

echo "Updating BTRFS label on $BTRFS_DEV"
btrfstune -L "BTRFS-$NEW" "$BTRFS_DEV"

echo "Updating EFI label on $EFI_DEV"
umount /boot/efi
fatlabel "$EFI_DEV" "EFI-$NEW"
mount /boot/efi

# Restore immutable bits
echo "Restoring immutable bits..."
chattr +i /boot/grub2/grub.cfg /etc/kernel/cmdline

echo ""
echo "Done. Verify with:"
echo "  grep -r '$NEW' /etc/fstab /etc/kernel/cmdline /boot/loader/entries/ /boot/efi/EFI/fedora/grub.cfg"

#----------------------------------------
