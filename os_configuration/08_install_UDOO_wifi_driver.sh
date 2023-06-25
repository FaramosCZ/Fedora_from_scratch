#!/bin/bash

#----------------------------------------
# Install UDOO wi-fi driver
#   The system has to be rebooted in order to this to take effect

dnf --comment="Install wi-fi driver for UDOO" install -y iwl3160-firmware

#----------------------------------------
