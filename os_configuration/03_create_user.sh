#!/bin/bash

#----------------------------------------
# Create the first user(s)
#   this is recommended to do before logging to the GUI for the first time,
#   as logging into GUI as root is sometimes glitchy and not expected in the first place

source ./user_conf.sh

useradd "$USER"
usermod -c "$USER_PRETTY" "$USER"
echo -e "$USER:$USER" | chpasswd

#----------------------------------------

