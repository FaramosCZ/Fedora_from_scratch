#!/bin/bash

#----------------------------------------
# Install favourite software

dnf -y --comment="Install favourite software" install tree tldr curl tar git zip unzip unrar openssl wget nano terminator ntfs-3g pip flatpak dnf-plugin-system-upgrade puzzles cmatrix cool-retro-term rsync
dnf -y --comment="Install maintenance software" install dnf-plugin-system-upgrade rsync speedtest-cli gnome-software
dnf -y --comment="Install fonts" install "google-noto-color-emoji*" dejavu-fonts-all

dnf -y --comment="Install user requested software" install chromium libreoffice inkscape gnome-calculator

dnf -y install brave-browser

dnf -y install EmptyEpsilon

# Install Discord as a flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install -y flathub com.discordapp.Discord

flatpak install -y flathub us.zoom.Zoom

#----------------------------------------

