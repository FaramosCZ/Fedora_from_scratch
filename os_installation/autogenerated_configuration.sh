#########################################
#
# AUTOMATICALLY GENERATED CONFIGURATION BASED ON USER PROVIDED CONFIGURATION
# DO NOT EDIT THIS CONFIGURATION BY HAND, USE USER CONFIGURATION FILES "*.conf"
#
#########################################

#----------------------------------------
# When BIOS/GPT or UEFI is used, it needs a speacial first partition, so we must fix the itearion over $DEVICE[i] later

MKFS_OFFSET=0;

# When BIOS && GPT is used, we need to create "BIOS Boot partition" at the beginning of the disk
if [ "$PARTITIONING_STANDARD" = "GPT" ] &&  [ "$FIRMWARE_INTERFACE" = "BIOS" ] ; then
  MKFS_OFFSET=1
fi

# When UEFI is used, we need to create "EFI" parition (of FAT filesystem type) at the beginning of the disk
if [ "$FIRMWARE_INTERFACE" = "UEFI" ] ; then
  MKFS_OFFSET=1
fi

#----------------------------------------

# When UEFI is used, we need to create "EFI" parition (of FAT filesystem type) at the beginning of the disk
if [ "$FIRMWARE_INTERFACE" = "UEFI" ] ; then
  PARTITION_FILESYSTEMS[0]="vfat"
  PARTITION_MOUNTPOINTS[0]="/boot/efi/"
  # Use label for the portable installations (won't depend on /dev/sd* path hardcoded into /etc/fstab)
  PARTITION_LABELS[0]="EFI"
fi

#----------------------------------------
