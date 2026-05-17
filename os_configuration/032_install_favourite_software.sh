#!/bin/bash

#----------------------------------------
# Install favourite software

dnf -y --comment="CLI tools" install tree tldr curl tar git zip unzip unrar openssl wget nano rsync
dnf -y --comment="Terminal emulator" install terminator
dnf -y --comment="System utilities" install ntfs-3g pip flatpak dnf-plugin-system-upgrade gnome-software speedtest-cli
dnf -y --comment="Fonts" install "google-noto-color-emoji*" dejavu-fonts-all
dnf -y --comment="Web browser" install brave-browser
dnf -y --comment="Games" install puzzles EmptyEpsilon cmatrix cool-retro-term

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.discordapp.Discord

#----------------------------------------

