#!/bin/bash

#----------------------------------------
# Restore Cinnamon DE settings
#   This has to be run as the user (all of the users) that are expected to use the GUI.
#   Note: I'm not sure if this command works even before the user logs into the GUI for the first time. Need testing.


btrfs_device=$(mount | grep " / " | awk '{print $1}')

# Mount root subvolume
mount -t btrfs -o subvol=/ "$btrfs_device" /mnt/ && cd /mnt/ && ls -alh
# Create readonly snapshot
btrfs subvolume snapshot -r boot RO-BACKUP_boot_system_setup_finished
#
ls -alh

#----------------------------------------
