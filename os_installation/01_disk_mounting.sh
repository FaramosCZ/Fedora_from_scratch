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
dnf install -y --repo=fedora-local util-linux coreutils || exit


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
umount -l "$DEVICE"* || :
umount -R -c "$MOUNTPOINT"/* || :

# Prepare the mount directory
[ -d "$MOUNTPOINT"  ] && rm -rf "$MOUNTPOINT"
mkdir -p "$MOUNTPOINT"

# Prepare file to store data for the /etc/fstab
rm -rf .tmp_fstab

# Create a new array, holding number of '/' contained  in each mountpoint path
for i in "${!PARTITION_MOUNTPOINTS[@]}"; do
  tmp=${PARTITION_MOUNTPOINTS[i]//"/"}
  PARTITION_MOUNTPOINTS_SLASH_COUNT[i]=$(((${#PARTITION_MOUNTPOINTS[i]} - ${#tmp})))
done

# Get the highest number in the new array
PARTITION_MOUNTPOINTS_SLASH_COUNT_HIGHEST=$( printf '%s\n' "${PARTITION_MOUNTPOINTS_SLASH_COUNT[@]}" | sort -nr | head -n1 )


# Mount the paths in the correct order
COUNTER=0
while [ $COUNTER -le "$PARTITION_MOUNTPOINTS_SLASH_COUNT_HIGHEST" ] ; do

  for i in "${!PARTITION_MOUNTPOINTS_SLASH_COUNT[@]}"; do
    if [ $COUNTER -eq ${PARTITION_MOUNTPOINTS_SLASH_COUNT[i]} ] ; then
      mkdir -p "$MOUNTPOINT${PARTITION_MOUNTPOINTS[i]}" || exit
      mount "$DEVICE"$((i+MKFS_OFFSET)) "$MOUNTPOINT${PARTITION_MOUNTPOINTS[i]}" || exit
      # Also prepare /etc/fstab entry right away
      if [ -z "${PARTITION_LABELS[i]}" ] ; then
        echo -e -n "$DEVICE"$((i+MKFS_OFFSET))"\t" >> .tmp_fstab || exit
      else
        echo -e -n "LABEL=${PARTITION_LABELS[i]}\t" >> .tmp_fstab || exit
      fi
      echo -e -n "${PARTITION_MOUNTPOINTS[i]}\t${PARTITION_FILESYSTEMS[i]}\t" >> .tmp_fstab || exit
      echo -e "defaults\t1\t$COUNTER" >> .tmp_fstab || exit
    fi
  done

  (( COUNTER++ ))
done


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
