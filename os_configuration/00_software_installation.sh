#!/bin/bash

#########################################
#
# AUTHOR:
#     Michal Schorm
#     mschorm@redhat.com
#     2019
#
# LICENSE:
#     MIT
#
# PURPOSE:
#     This script is part of a bigger project.
#     This particular script deals with a disk partitioning before you install a new OS.
#
# GOALS:
#     To produce simple, well-commented, easily understandable code, which could be highly reusable and hopefully portable.
#
# DESCRIPTION:
#     Using 'sfdisk', beacuse it is "script-firendly"
#     Using 'mkfs.*' to create the underlying FS right away.
#
# RUNTIME NOTES:
#     Since we are dealing with disk partitioning, you have to run this script with elevated priviledges. (e.g. root)
#     Always run only after making sure, the data on the attached disks are disposable.
#
#     This script shouldn't be modified if you *really* don't know what you are doing.
#     For USER CONFIGURATION, use the *.conf files instead, in the same directory. (disk_parititoning.conf)
#
# AUTHOR NOTES:
#     The script was writtent to run as a part of custom Fedora 30 installation. So I'm assuming Fedora environment (/bin/bash; DNF; ...)
#
#########################################


#----------------------------------------
# PREPARE THE ENVIRONMENT

# Use set -v to print the shell input lines as they are read
# Use set -x to print the shell input lines after expansion
set -vx


#----------------------------------------
# LOAD CONFIGURATION

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy source of information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" || exit

# Load the USER CONFIGURATION from a separate file
source ./software_installation.conf || exit


#----------------------------------------
# INSTALL THE FREE & NON-FREE RPMFUSION REPOSITORIES

dnf install -y --nogpgcheck $DNF_ARGS \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" \
  fedora-workstation-repositories \
  fedora-repos-rawhide

dnf config-manager --set-enabled google-chrome

#----------------------------------------
# INSTALL THE ADITIONAL SOFTWARE

dnf install -y $DNF_ARGS $SOFTWARE_TO_INSTALL $RPMFUSION_SOFTWARE_TO_INSTALL

#----------------------------------------

# Jump back to the directory we were before this script execution
popd
