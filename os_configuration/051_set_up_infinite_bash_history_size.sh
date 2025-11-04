#!/bin/bash



#----------------------------------------
# Set up infinite bash history

cat << EOF >> /etc/profile.d/z_infinite_bash_history.sh

# From 'man bash':
#   HISTFILESIZE
#          The maximum number of lines contained in the history file.  When this variable is assigned a value, the history file is truncated, if necessary, to contain no more than that number of lines by removing the  oldest  en‐
#          tries.  The history file is also truncated to this size after writing it when a shell exits.  If the value is 0, the history file is truncated to zero size.  Non-numeric values and numeric values less than zero inhibit
#          truncation.  The shell sets the default value to the value of HISTSIZE after reading any startup files.
#   HISTSIZE
#          The  number  of commands to remember in the command history (see HISTORY below).  If the value is 0, commands are not saved in the history list.  Numeric values less than zero result in every command being saved on the
#          history list (there is no limit).  The shell sets the default value to 500 after reading any startup files.

HISTSIZE=-1
HISTFILESIZE=-1

EOF

#----------------------------------------
