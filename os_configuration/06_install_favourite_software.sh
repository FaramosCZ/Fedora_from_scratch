#!/bin/bash

#----------------------------------------
# Install favourite software

dnf -y --comment="Install favourite software" install tree tldr curl tar git zip unzip openssl wget nano terminator ntfs-3g unicode-emoji pip "google-noto-emoji*" flatpak dnf-plugin-system-upgrade puzzles cmatrix cool-retro-term

# Install Discord as a flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install -y flathub com.discordapp.Discord

#----------------------------------------

