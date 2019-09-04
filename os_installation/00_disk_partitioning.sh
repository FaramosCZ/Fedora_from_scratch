#!/bin/bash

#########################################
#
# AUTHOR:
#     Michal Schorm
#     mschorm@redhat.com
#     2019
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
#     Using 'sfdisk', beacuse it is "script-firendly"
#     Using 'mkfs.*' to create the underlying FS right away.
#
# RUNTIME NOTES:
#     Since we are dealing with disk partitioning, you have to run this script with elevated priviledges. (e.g. root)
#     Always run only after making sure, the data on the attached disks are disposable.
#
#     This script shouldn't be modified if you *really* don't know what you are doing.
#     For USER CONFIGURATION, use the *.conf files instead, in the same directory. (disk_parititoning.conf)
#
# AUTHOR NOTES:
#     The script was writtent to run as a part of custom Fedora 30 installation. So I'm assuming Fedora environment (/bin/bash; DNF; ...)
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
dnf install -y util-linux coreutils || exit


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
swapoff "$DEVICE"* || :
umount -l "$DEVICE"* || :
umount -R -c "$MOUNTPOINT"/* || :

sync
sleep 5;

# Create desired layout of the partition tables
[ "$PARTITIONING_STANDARD" = "GPT" ] && PARTITIONING_STANDARD_LABEL="gpt" || PARTITIONING_STANDARD_LABEL="mbr" && \
echo "label: $PARTITIONING_STANDARD_LABEL" | sfdisk "$DEVICE" || exit


#----------------------------------------
# CREATE PARTITITONS

# First of all, add partitions requested by the USER CONFIGURATION
for i in "${!PARTITION_SIZES[@]}"; do
  SFDISK_INPUT[i]=";${PARTITION_SIZES[i]};;"
done

# When BIOS && GPT is used, we need to create "BIOS Boot partition" at the beginning of the disk
if [ "$PARTITIONING_STANDARD" = "GPT" ] && [ "$FIRMWARE_INTERFACE" = "BIOS" ] ; then
  SFDISK_INPUT[0]=";1M;21686148-6449-6E6F-744E-656564454649;"
# When UEFI is used, we need to create EFI partition at the beginning of the disk
# However it's identificator differs for MBR and GPT
elif [ "$FIRMWARE_INTERFACE" = "UEFI" ] ; then
  PARTITION_SIZES[0]="200M"
  if [ "$PARTITIONING_STANDARD" = "MBR" ] ; then
    SFDISK_INPUT[0]=";${PARTITION_SIZES[0]};ef;"
  elif [ "$PARTITIONING_STANDARD" = "GPT" ] ; then
    SFDISK_INPUT[0]=";${PARTITION_SIZES[0]};C12A7328-F81F-11D2-BA4B-00A0C93EC93B;"
  fi
fi

# Execute the 'sfdisk' utility
printf '%s\n' "${SFDISK_INPUT[@]}" | sfdisk "$DEVICE" || exit


#----------------------------------------
# CREATE FILESYSTEMS ON PREPARED PARTITIONS

# Create filesystem; use 'a' to overwrite any FS that was present
for i in "${!PARTITION_FILESYSTEMS[@]}"; do
  # If we've got a label for that filesystem from the USER CONFIGURATION, use it
  if [ -z "${PARTITION_LABELS[i]}" ] ; then
    echo a | mkfs."${PARTITION_FILESYSTEMS[i]}" "$DEVICE"$((i+MKFS_OFFSET)) || exit
  else
    echo a | mkfs."${PARTITION_FILESYSTEMS[i]}" -L "${PARTITION_LABELS[i]}" "$DEVICE"$((i+MKFS_OFFSET)) || exit
  fi
done


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
#        Instead of running Anaconda, yoou run this set of scripts.
#        Thus assuming software standardly available in such images.
#
#     3) So far can prepare one disk only.
#        If this extended functionality would be wanted, new array has to be added, holding the appropriate disk / device for each parititon.
#
#     4) Sometimes the script will fail on disk manipulation with various errors, like "resource busy" etc.
#        Usually re-run will solve those errors. However if you see after 3rd execution still the same error, check your system or this code.
#
#########################################
