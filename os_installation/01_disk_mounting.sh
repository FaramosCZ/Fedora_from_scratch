#!/bin/bash

#########################################
#
# AUTHOR:
#     Michal Schorm
#     mschorm@redhat.com
#     2021
#
# LICENSE:
#     MIT
#
# PURPOSE:
#     This script is part of a bigger project.
#     This particular script solves mounting freshly partitioned disk before you install a new OS.
#
# GOALS:
#     To produce simple, well-commented, easily understandable code, which could be highly reusable and hopefully portable.
#
# DESCRIPTION:
#     Clears selected mountpoint and mounts the disks into it in a correct order
#
# RUN-TIME NOTES:
#     This script will call 'rm -rf' onto the mountpoint. Make sure there aren't any data you may miss.
#     You have to run this script with elevated privileges. (e.g. root)
#     Always run only after making sure, the data on the attached disks are disposable.
#
#     This script shouldn't be modified if you *really* don't know what you are doing.
#     For USER CONFIGURATION, use the *.conf files instead, in the same directory. (disk_partitioning.conf)
#
# AUTHOR NOTES:
#     The script was written to run as a part of custom Fedora 30 installation. So I'm assuming Fedora environment (/bin/bash; DNF; ...)
#
#########################################


#----------------------------------------
# PREPARE THE ENVIRONMENT

# Use set -v to print the shell input lines as they are read
# Use set -x to print the shell input lines after expansion
set -vx

# Make sure we have all of the required software
#   'mount' utility lives in the 'util-linux' package
#   'chcon' utility lives in the 'coreutils' package
dnf install -y util-linux coreutils || exit


#----------------------------------------
# LOAD CONFIGURATION

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" || exit

# Load the configuration from a separate file
source ./disk_partitioning.conf || exit


#----------------------------------------
# MOUNT THE DISKS IN THE CORRECT ORDER

# Make sure all partitions are unmounted
umount -l "$(DISK_NAME)"* || :
umount -R -c "$MOUNTPOINT"/* || :

# Prepare the mount directory
[ -d "$MOUNTPOINT"  ] && rm -rf "$MOUNTPOINT"
mkdir -p "$MOUNTPOINT"

# Prepare file to store data for the /etc/fstab
rm -rf .tmp_fstab


#----------------------------------------

# Create a directory for a mount point
mkdir -p "$MOUNTPOINT""/" || exit

# Mount the root of the BTRFS there
mount -t btrfs "$(DISK_NAME 2)" "$MOUNTPOINT" || exit
# Create a subvolume that will act as a root for our filesystem
btrfs subvolume create "$MOUNTPOINT""/root" || exit
# Also create a symlink to it, which will be used by GRUB EFI confiuration
pushd "$MOUNTPOINT"
ln -s "root" "boot" || exit
popd
# Mount the new subvolume instead
umount "$MOUNTPOINT" || exit
mount -t btrfs -o subvol="boot" "$(DISK_NAME 2)" "$MOUNTPOINT" || exit

# Create a directory for EFI partition mount point
mkdir -p "$MOUNTPOINT""/boot/efi/" || exit
# And mount the EFI partition inside
mount "$(DISK_NAME 1)" "$MOUNTPOINT""/boot/efi/" || exit

cat << EOF > .tmp_fstab || exit
LABEL=EFI    /boot/efi/  vfat   defaults     0  2
LABEL=BTRFS  /           btrfs  subvol=boot  0  0
EOF

#----------------------------------------

# Mount the rest of the directories from the running system
# Mount before installing anything since many scriptlets assume existence of /dev/*
mkdir "$MOUNTPOINT"/sys "$MOUNTPOINT"/proc "$MOUNTPOINT"/dev || :

# To fix the bug in SELinux labeling rhbz#1467103 rhbz#1714026
chcon --reference=/dev "$MOUNTPOINT"/dev || exit

mount -t sysfs none "$MOUNTPOINT"/sys || exit
mount -t proc  none "$MOUNTPOINT"/proc || exit
mount -o bind  /dev "$MOUNTPOINT"/dev || exit


#----------------------------------------

# Jump back to the directory we were before executing of this script
popd

#########################################
#
# KNOWN BUGS & LIMITATIONS:
#
#     1) This script was tested ONLY on x86_64 architecture. It should be architecture independent, but without proper testing, who knows? :)
#
#     2) This script was tested running ONLY from official Fedora Cinnamon installer images from getfedora.org.
#        Instead of running Anaconda, you run this set of scripts.
#        Thus assuming software by default available in such images.
#
#     3) So far can prepare one disk only.
#        If this extended functionality would be wanted, new array has to be added, holding the appropriate disk / device for each parititon.
#
#     4) There's a bug in automatic SELinux relabeling:
#        rhbz#1467103 rhbz#1714026
#
#########################################
