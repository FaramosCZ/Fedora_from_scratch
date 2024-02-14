#!/bin/bash

#----------------------------------------
# Restore Cinnamon DE settings
#   This has to be run as the user (all of the users) that are expected to use the GUI.
#   Note: I'm not sure if this command works even before the user logs into the GUI for the first time. Need testing.

source ./user_conf.sh

su -c "dconf load /org/cinnamon/ < ./cinnamon_desktop_backup" "$USER"
su -c "cinnamon --replace >/dev/null 2>&1 &" "$USER"

# Restore XED configuration
su -c "dconf load /org/x/editor/preferences/ < ./xed_configuration_backup" "$USER"

# Language & Locale for the non-root user
su -c "localectl set-locale LANG=en_US.UTF-8" "$USER"
su -c 'localectl set-x11-keymap cz,us " " , grp:alt_shift_toggle' "$USER"

#----------------------------------------
