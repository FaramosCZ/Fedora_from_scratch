#!/bin/bash

#----------------------------------------
# CHECK THAT WE ARE RUNNING AS ROOT

if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root"
  exit
fi

#----------------------------------------
# SET UP A RELATIVE PATH

# Determine and set the relative path we are on
#   $BASH_SOURCE is the only trustworthy source of information. But it does not follow symlinks - use readlink to get canonical path
relative_path=$( readlink -f "$BASH_SOURCE" )
# Move to the current script location, to assure relative paths will be configured correctly
pushd "${relative_path%/*}" || exit

#----------------------------------------
# RUN ALL THE SCRIPTS IN THIS DIRECTOY IN THE CORRECT ORDER

for SCRIPT in ./0*.sh; do
    echo "$SCRIPT" | tee -a autorun.log
    sh "$SCRIPT" 2>&1 | tee -a autorun.log
done

#----------------------------------------

# Jump back to the directory we were before this script execution
popd
