#!/bin/bash

#----------------------------------------
# Restore Cinnamon DE settings
#   This has to be run as the user (all of the users) that are expected to use the GUI.
#   Note: I'm not sure if this command works even before the user logs into the GUI for the first time. Need testing.

su -c "dconf load /org/cinnamon/ < ./cinnamon_desktop_backup" udoo

#----------------------------------------
