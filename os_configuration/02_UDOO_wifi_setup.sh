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


#----------------------------------------
# LOAD CONFIGURATION

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy source of information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" || exit

# Load the USER CONFIGURATION from a separate file
source ./software_installation.conf || exit


#----------------------------------------

# Prepare kernel to support wifi
dnf install -y --nogpgcheck kernel-modules iwl3160-firmware
echo "blacklist i2c_i801" >> /etc/modprobe.d/blacklist.conf
kernel-install add "$(uname -r)" /lib/modules/"$(uname -r)"/vmlinuz

# Wi-Fi
dnf --comment="nmcli, wifi" install -y --nogpgcheck NetworkManager-wifi dnsmasq

#   # dmesg | grep iwlwifi -> iwlwifi 0000:03:00.0: Direct firmware load for iwlwifi-3168-23.ucode failed with error -2
#   https://www.intel.com/content/www/us/en/wireless-products/dual-band-wireless-ac-3168-brief.html
#   https://www.intel.com/content/www/us/en/support/articles/000005511/network-and-i-o/wireless-networking.html
#   https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi-3168-ucode-22.361476.0.tgz
#   README, /lib/firmware
#cd /tmp && wget https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi-3168-ucode-22.361476.0.tgz && tar -xof iwlwifi-3168-ucode-22.361476.0.tgz && cp iwlwifi-3168-ucode-22.361476.0/iwlwifi-3168-22.ucode /lib/firmware


exit
# !! REBOOT !!
reboot
# !! REBOOT !!

nmcli con add type wifi ifname wlp3s0 con-name UDOO-Hotspot autoconnect no ssid UDOO-Hotspot
nmcli con modify UDOO-Hotspot 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
nmcli con modify UDOO-Hotspot wifi-sec.key-mgmt wpa-psk
nmcli con modify UDOO-Hotspot wifi-sec.psk "password"
nmcli connection modify UDOO-Hotspot connection.autoconnect-priority 1
nmcli con up UDOO-Hotspot
nmcli con down UDOO-Hotspot

# Connect to regular Wi-FI by
nmcli device wifi list
nmcli device wifi connect <ssid> --ask



#----------------------------------------

# Jump back to the directory we were before this script execution
popd
