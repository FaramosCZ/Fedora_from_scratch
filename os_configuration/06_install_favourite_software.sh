#!/bin/bash

#----------------------------------------
# Install favourite software

dnf -y --comment="Install favourite software" install tree tldr curl tar git zip unzip openssl wget nano terminator fwupd ntfs-3g unicode-emoji pip "google-noto-emoji*" flatpak dnf-plugin-system-upgrade

#----------------------------------------

