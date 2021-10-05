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
#     This particular script solves installing the OS into the mounted disk
#
# GOALS:
#     To produce simple, well-commented, easily understandable code, which could be highly reusable and hopefully portable.
#
# DESCRIPTION:
#     Installs the core system - a headless server, adds the set of custom packages and sets up networking in the mounted system.
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
# INSTALL BASIC SOFTWARE

# Check there's valid space to install into
[ ! -d "$MOUNTPOINT" ] && exit 1

# Don't assume the OS version we are currently in. Prepare custom repository to get packages from.
echo "\
[fedora-custom]
name=fedora-custom
enabled=1
gpgcheck=0
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-$OS&arch=x86_64" \
 > /etc/yum.repos.d/fedora-custom.repo

# Install core software inside the mounted directory tree
dnf --comment="Install the DNF group @core" --releasever="$OS" --installroot="$MOUNTPOINT" -y $DNF_ARGS --nogpgcheck --repo="fedora-custom" groupinstall core

# Install the favourite software inside
# NOTE: DNF will prioritize the configuration inside "--installroot", so we don't need to use our custom repo anymore.
#       If we would like to use the Host system repo instead, we would need to use "--setopt=reposdir=..." to force repos on Host to be priotitized.
dnf --comment="Install custom packages which I want to be part of the minimal installation" --releasever="$OS" --installroot="$MOUNTPOINT" -y $DNF_ARGS --nogpgcheck install $CUSTOM_CORE_PACKAGES

# Make sure the kernel was installed too
# MAYBE BUG: sometimes (e.g. when installing Fedora Beta release), the kernel won't install ... why? That's mystery. Let's make sure we have it.
dnf --comment="Install kernel" --releasever="$OS" --installroot="$MOUNTPOINT" -y $DNF_ARGS --nogpgcheck install $CUSTOM_KERNEL_PACKAGES

# Copy network resolution file into the mounted system
cp /etc/resolv.conf "$MOUNTPOINT"/etc/

# Set up device name
echo "$DEVICE_NAME" > "$MOUNTPOINT"/etc/hostname


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
#########################################
