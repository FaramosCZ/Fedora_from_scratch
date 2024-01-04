#!/bin/bash

#----------------------------------------
# Display the current LAN IP address before the login prompts on TUI TTYs

LAN=$(ip -br a | grep enp | awk '{print $1}')

echo -e "\
IP LAN: \4{"$LAN"}
" > /etc/issue

#----------------------------------------
