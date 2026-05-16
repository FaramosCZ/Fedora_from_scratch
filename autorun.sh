#!/bin/bash

#----------------------------------------
# LOGGING

install_log="$(pwd)/os_installation.log"
exec > >(tee "$install_log") 2>&1

#----------------------------------------
# SET UP A RELATIVE PATH

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy source of information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" > /dev/null || exit

#----------------------------------------
# RUN ALL THE AUTORUN SCRIPTS

pushd os_installation > /dev/null
python3 -u main.py
popd > /dev/null

#----------------------------------------

echo -e "\tLog saved to: ${install_log}"
echo -e "\tTime elapsed: $((SECONDS / 60))m $((SECONDS % 60))s\n"

# Copy the install log into the installed system
cp "$install_log" /mnt/FEDORA_FROM_SCRATCH/root/

# Jump back to the directory we were before this script execution
popd > /dev/null
