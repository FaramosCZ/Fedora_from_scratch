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
#     This particular script deals with a disk partitioning before you install a new OS.
#
# GOALS:
#     To produce simple, well-commented, easily understandable code, which could be highly reusable and hopefully portable.
#
# DESCRIPTION:
#     Using 'sfdisk', because it is "script-friendly"
#     Using 'mkfs.*' to create the underlying FS right away.
#
# RUN-TIME NOTES:
#     Since we are dealing with disk partitioning, you have to run this script with elevated privileges. (e.g. root)
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
#   All of the 'sfdisk', 'mkfs' and 'mount' utilities lives in the 'util-linux' package
#   The 'readlink' utility is in the 'coreutils' package
#   The 'btrfs-progs' obviously for tools for working with BTRFS
#   The 'dosfstools' offers the 'mkfs.vfat' required for creating an EFI parition filesystem
dnf install -y util-linux coreutils btrfs-progs dosfstools || exit


#----------------------------------------
# LOAD CONFIGURATION

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy source of information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" || exit

# Load the USER CONFIGURATION from a separate file
source ./disk_partitioning.conf || exit


#----------------------------------------
# PREPARE THE DISK LAYOUT

# Make sure all partitions are unmounted
swapoff -a || :
swapoff "$(DISK_NAME)"* || :
umount -l "$(DISK_NAME)"* || :
umount -R -c "$MOUNTPOINT"/* || :

sync
sleep 3;

#----------------------------------------

# Create modern GPT layout of the partition tables
echo "label: gpt" | sfdisk "$(DISK_NAME)" || exit
sleep 1;


#----------------------------------------
# CREATE PARTITIONS

# When UEFI is used, we need to create EFI partition at the beginning of the disk
#   50 MB should be more than enough in case of Fedora. The required space depends mainly
#   on the bootloader and its choice which data to store on EFI and which elsewhere.
SFDISK_INPUT[0]=";50M;C12A7328-F81F-11D2-BA4B-00A0C93EC93B;"

# The only other thing on the disk will be a single BTRFS partition covering the rest of the space
# When size is set bigger than what the real disk size is, maximum left disk space is used instead
SFDISK_INPUT[1]=";99T;;"

# Execute the 'sfdisk' utility
printf '%s\n' "${SFDISK_INPUT[@]}" | sfdisk "$(DISK_NAME)" || exit


#----------------------------------------

# Create filesystem on the EFI partition
#   use 'a' to overwrite any FS that was present
echo a | mkfs.vfat -n "EFI-MMCBLK" "$(DISK_NAME 1)" || exit

# Create filesystem on the BTRFS partition
#   use 'a' to overwrite any FS that was present
echo a | mkfs.btrfs -f -L "BTRFS-MMCBLK" "$(DISK_NAME 2)" || exit


#----------------------------------------

# Jump back to the directory we were before this script execution
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
#        If this extended functionality would be wanted, new array has to be added, holding the appropriate disk / device for each partition.
#
#     4) Sometimes the script will fail on disk manipulation with various errors, like "resource busy" etc.
#        Usually re-run will solve those errors. However if you see after 3rd execution still the same error, check your system or this code.
#
#########################################
