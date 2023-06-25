#!/bin/bash

#----------------------------------------
# Install additional repositories
#   RPM Fusion: https://rpmfusion.org/
#   Fedora Third-party repositories: https://docs.fedoraproject.org/en-US/workstation-working-group/third-party-repos/
#   Fedora Rawhide: https://docs.fedoraproject.org/en-US/releases/rawhide/

dnf --comment="Enable additional repositories" install -y \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
  fedora-workstation-repositories \
  fedora-repos-rawhide

dnf config-manager --set-enabled google-chrome

#----------------------------------------

