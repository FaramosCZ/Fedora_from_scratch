#!/bin/bash

#----------------------------------------
# Create the first user(s)
#   this is recommended to do before logging to the GUI for the first time,
#   as logging into GUI as root is sometimes glitchy and not expected in the first place

source ./user_conf.sh

useradd "$USER"
usermod -c "$USER_PRETTY" "$USER"
echo -e "$USER:$USER" | chpasswd

# Bluetooth GUI client 'bluez' utilizes polkit rules, which require the user to be in the 'wheel' group,
# in order to be able to control the BT ON/OFF state
# Otherwise it will spam the user with very annoying pop-up window asking for root password after every login.
usermod -a -G wheel "$USER"

#----------------------------------------

