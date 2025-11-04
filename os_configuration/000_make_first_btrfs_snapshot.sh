#!/bin/bash

#----------------------------------------
# Create a backup - BTRFS snapshot

# Mount BTRFS root subvolume
#   Use prepared mount configuration from /etc/fstab
mount --target=/mnt/BTRFS-ROOT && pushd /mnt/BTRFS-ROOT

# Create readonly snapshot
btrfs subvolume snapshot -r boot RO-BACKUP-01-minimal_headless_server_setup_finished

popd

#----------------------------------------
