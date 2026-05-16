#!/bin/bash

#----------------------------------------
# Set locale and timezone

# Language & Locale
localectl set-locale LANG=en_US.UTF-8
localectl set-x11-keymap cz,us " " , grp:alt_shift_toggle

# Set timezone
ln -s /usr/share/zoneinfo/Europe/Prague /etc/localtime

#
echo -e "\nSynchronizing time with network:"
systemctl enable --now systemd-timesyncd
echo -e "\t" `date` "\n\n"

#----------------------------------------

