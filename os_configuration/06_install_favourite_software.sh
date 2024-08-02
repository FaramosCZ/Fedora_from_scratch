#!/bin/bash

#----------------------------------------
# Install favourite software

dnf -y --comment="Install favourite software" install tree tldr curl tar git zip unzip openssl wget nano terminator ntfs-3g pip flatpak dnf-plugin-system-upgrade puzzles cmatrix cool-retro-term
dnf -y --comment="Install fonts" install unicode-emoji "google-noto-emoji*" dejavu-fonts-all

dnf -y --comment="Install user requested software" install chromium libreoffice inkscape

# Install Discord as a flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install -y flathub com.discordapp.Discord
flatpak install -y flathub io.freetubeapp.FreeTube

flatpak install -y flathub us.zoom.Zoom
flatpak install -y flathub com.skype.Client

#----------------------------------------

