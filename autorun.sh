#!/bin/bash

#----------------------------------------
# SET UP A RELATIVE PATH

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy source of information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" || exit

#----------------------------------------
# RUN ALL THE AUTORUN SCRIPTS

pushd os_installation
python3 main.py
popd

#----------------------------------------

# Jump back to the directory we were before this script execution
popd
