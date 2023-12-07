#!/bin/bash

#----------------------------------------
# GUI installation
#   I'm installing the GUI via DNF package 'groups'.
#   That's really handy, but it also contains a lot of bloatware. Let's keep the package set minimal
#   The second remove call drops: CJK input methods (only en+cs needed), accessibility TTS/on-screen keyboard,
#   unused icon/wallpaper themes, weather data, emoji metadata for all languages, and Unicode character DB
#   Note: caribou, gnome-backgrounds, gucharmap, cinnamon-translations are bloat
#   but cannot be removed — cinnamon hard-depends on them (translations via cinnamon-screensaver)

dnf -y --comment="Install the Cinnamon DE" group install cinnamon-desktop
dnf -y --comment="Remove the bloatware" -x cinnamon -x xorg-x11-* -x lsof -x boost* -x chrony -x "flatpak*" remove "dnfdragora-*" pidgin xfburn thunderbird xawtv shotwell ImageMagick "*anaconda*" trousers yelp redshift mpv gnome-calculator gnome-calendar plymouth "fwupd*" PackageKit deltarpm enchant exiv2 fortune-mod "geolite*" hexchat kpartx nilfs-utils "onboard*" "pcsc-lite*" "*evolution*"
dnf -y --comment="Remove the bloatware - CJK, accessibility, unused themes and data" remove ibus-anthy ibus-anthy-python anthy-unicode ibus-chewing libchewing ibus-hangul libhangul ibus-libpinyin libpinyin-data ibus-m17n ibus-typing-booster cldr-emoji-annotation speech-dispatcher espeak-ng flite paper-icon-theme libmateweather-data unicode-ucd

dnf -y --comment="Install the Audio Tooling" install alsa-utils pulseaudio-utils
dnf -y --comment="Install the Audio Firmware" install alsa-sof-firmware
#dnf -y --comment="Install the Most Restricted Audio Video Codecs" install http://rpm.livna.org/livna-release.rpm
dnf -y --comment="Install the VLC and Audacity with more Audio Video Codecs" install --allowerasing vlc audacity ffmpeg-libs ffmpeg
dnf -y --comment="Install the RPM Fusion Audio and Video Codecs" install --allowerasing gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly libavcodec-freeworld vlc-plugins-freeworld

dnf -y --comment="Gaming tools" install lutris steam protontricks wine

dnf -y --comment="NVidia drivers" install /usr/bin/nvidia-smi kmod-nvidia -x xorg-x11-drv-nvidia-power
# wait for the DNF transaction lock to be freed by the NVIDIA driver background installation
sleep 120

#----------------------------------------

