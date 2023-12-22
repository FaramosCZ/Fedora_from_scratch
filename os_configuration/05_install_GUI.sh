#!/bin/bash

#----------------------------------------
# GUI installation
#   I'm installing the GUI via DNF package 'groups'.
#   That's really handy, but it also contains a lot of bloatware. Let's keep the package set minimal

dnf -y --comment="Install the Cinnamon DE" groupinstall cinnamon
dnf -y --comment="Remove the bloatware" -x cinnamon -x xorg-x11-* -x lsof -x boost* -x chrony -x "flatpak*" remove "dnfdragora-*" pidgin xfburn thunderbird xawtv shotwell ImageMagick "*anaconda*" trousers yelp redshift mpv gnome-calculator gnome-calendar plymouth

dnf -y --comment="Install the Audio Tooling" install alsa-utils pulseaudio-utils
dnf -y --comment="Install the Audio Firmware" install alsa-sof-firmware
dnf -y --comment="Install the Most Restricted Audio Video Codecs" install http://rpm.livna.org/livna-release.rpm
dnf -y --comment="Install the VLC and Audacity with more Audio Video Codecs" install vlc audacity ffmpeg-libs ffmpeg
dnf -y --comment="Install the Audio and Video Codecs" groupupdate Multimedia

#----------------------------------------

