#!/bin/bash

#----------------------------------------

bind 'set enable-bracketed-paste off' 2>/dev/null
read -p "Set this machine HOSTNAME: " -e -i "FARAMOS-NTB-" new_hostname

echo "$new_hostname" > /etc/hostname

#----------------------------------------
