#!/bin/bash

#----------------------------------------
# Install the general wi-fi drivers
#   The system has to be rebooted in order to this to take effect

dnf -y --comment="Install the general wi-fi drivers" install iwlwifi-mvm-firmware iwlwifi-dvm-firmware iwlegacy-firmware

# In case of issue package 'iwlegacy-firmware' can be tried
# or package 'broadcom-wl', but it taints the kernel

#----------------------------------------
