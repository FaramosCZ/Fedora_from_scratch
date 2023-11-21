#!/bin/bash

#----------------------------------------
# Install the general wi-fi driver
#   The system has to be rebooted in order to this to take effect

dnf --comment="Install the general wi-fi driver" install -y iwlwifi-mvm-firmware

#----------------------------------------
