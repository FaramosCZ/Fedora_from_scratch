#!/bin/bash

#----------------------------------------
# Install the general wi-fi drivers
#   The system has to be rebooted in order to this to take effect

dnf --comment="Install the general wi-fi drivers" install -y iwlwifi-mvm-firmware iwlwifi-dvm-firmware

#----------------------------------------
