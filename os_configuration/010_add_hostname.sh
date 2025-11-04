#!/bin/bash

#----------------------------------------

read -p "Set this machine HOSTNAME: " -e -i "FARAMOS-NTB-" new_hostname

echo "$new_hostname" > /etc/hostname

#----------------------------------------
