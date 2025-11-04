#!/bin/bash

#----------------------------------------
# Set up infinite terminator scrollback

source ./user_conf.sh

cp -a --remove-destination ./DATA/terminator /home/"$USER"/.config/
chown -R "$USER":"$USER" /home/"$USER"/.config/

#----------------------------------------
