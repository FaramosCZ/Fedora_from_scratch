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
#     Configures the core system inside chroot before the first startup.
#
# RUN-TIME NOTES:
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


#----------------------------------------
# LOAD CONFIGURATION

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" || exit

# Load the configuration from a separate file
source ./disk_partitioning.conf || exit
source ./system_installation.conf || exit


#----------------------------------------
# CONFIGURE THE CORE SYSTEM IN CHROOT

# Check there's valid space to install into
[ -d "$MOUNTPOINT" ] || exit

# Chroot inside
cat << EOF | chroot "$MOUNTPOINT" /bin/bash || exit

    # Use set again
    set -vx


    # BUG: rhbz#1645118
      # Set up root password
      # echo -e "root:root" | chpasswd
    # WORKAROUND: rhbz#1645118
    # Remove line for user "root"
    sed -i '/^root/ d' /etc/shadow
    echo '$ROOT_PASSWORD_HASH' >> /etc/shadow


    # Tell SELinux to repair context to all files at first startup
    touch /.autorelabel


    echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    # Install GRUB (while in chroot)
    if [ "$FIRMWARE_INTERFACE" = "UEFI" ] ; then
      dnf install -y $DNF_ARGS grub2-efi-x64 shim || exit
      grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg || exit
    else
      dnf install -y $DNF_ARGS grub2-pc-modules || exit
      grub2-install "$DEVICE" || exit
      grub2-mkconfig -o /boot/grub2/grub.cfg || exit
    fi
    grub2-switch-to-blscfg || exit


    # Re-declare the array, since we jumped to chroot
    SERVICES_TO_ENABLE=("${SERVICES_TO_ENABLE[@]}")
    # Enable desired services, if any was set
    [ -n "${SERVICES_TO_ENABLE[*]}" ] && \
    for service in "${SERVICES_TO_ENABLE[@]}"; do systemctl enable "\$service"; done


    # Update all packages to the latest version
    dnf update -y $DNF_ARGS
    # Make sure the kernel was installed; reinstall it to re-generate the GRUB boot entries
    dnf reinstall -y $DNF_ARGS $CUSTOM_KERNEL_PACKAGES

EOF


# Add fstab entries prepared by previous script
mkdir -p "$MOUNTPOINT"/etc
# Check the old version, if any
cat "$MOUNTPOINT"/etc/fstab || :
rm -rf "$MOUNTPOINT"/etc/fstab
cp .tmp_fstab "$MOUNTPOINT"/etc/fstab || exit
# Check the new version
cat "$MOUNTPOINT"/etc/fstab


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
#     3) There's bug preventing any password manipulation in chroot or in a system where systemd is not running
#        rhbz#1645118
#
#########################################
