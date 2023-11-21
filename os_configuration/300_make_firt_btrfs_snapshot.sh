#!/bin/bash

#----------------------------------------
# Restore Cinnamon DE settings
#   This has to be run as the user (all of the users) that are expected to use the GUI.
#   Note: I'm not sure if this command works even before the user logs into the GUI for the first time. Need testing.


#device_of_the_root_fs="/dev/sda3"
#device_of_the_root_fs="/dev/nvmen0p4"
device_of_the_root_fs=$(mount | grep " / " | awk '{print $1}')
last_num_cut=${device_of_the_root_fs%?}
echo ${last_num_cut: -1}
if [ "${last_num_cut: -1}" = "p" ]; then
    last_num_cut=${last_num_cut%?}
fi
root_fs_name = "$last_num_cut"


# Mount root subvolume
mount -t btrfs -o subvol=/ "$root_fs_name" /mnt/ && cd /mnt/ && ls -alh
# Create readonly snapshot
btrfs subvolume snapshot -r boot RO-BACKUP_boot_system_setup_finished
#
ls -alh

#----------------------------------------
