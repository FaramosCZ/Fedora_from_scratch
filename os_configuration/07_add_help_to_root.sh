#!/bin/bash

#----------------------------------------
# Add help to root shell prompt

cat << EOF >> /root/.bashrc

# CUSTOM SETTINGS BY FARAMOS

# Set up my favourite text editor as a system default one
export EDITOR=nano
export UAEDITOR=nano
export VISUAL=nano

alias L='ls -Alh'
alias IP='ip -c a'
alias N='nano '

alias GS='git status'
alias GCH='git checkout '
alias GBA='git branch -a'

alias DMESG='dmesg --level=err,warn -w '

alias HELP='echo -e "
  # Set ssh key authentification from guest to host
  ssh-copy-id <user>@<machine>

  # Connect with password over SSH instead of a key
  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no 10.0.0.1

  # Set firewall
  firewall-cmd --add-port=6667/tcp
  firewall-cmd --runtime-to-permanent

  # Allow user to install software
  echo \"<user> ALL= NOPASSWD: /usr/bin/dnf\" >> /etc/sudoers.d/<username>

  # Useful commands for login track
  aureport -au -i
  last
  lastb
  lastlog

TERMINATOR:
    ctrl + shift + o   =   split hozizontaly
    ctrl + shift + e   =   split vertically
    ctrl + shift + t   =   new tab
    ctrl + shift + x   =   full screen single selected terminal
    ctrl + alt + w     =   change window title

PIP
    python -m venv env
    source ./env/bin/activate
    pip freeze > requirements.txt
    pip install -r requirements.txt

BTRFS
    # mount root subvolume
    mount -t btrfs -o subvol=/ /dev/mmcblk0p2 /mnt/ && cd /mnt/ && ls -alh
    # create readonly snapshot
    btrfs subvolume snapshot -r <original> <new_snapshot>

SYSTEMCTL
    systemctl isolate multi-user.target
    systemctl isolate graphical.target
    systemctl set-default multi-user.target

"
'

# END OF CUSTOM SETTINGS BY FARAMOS

EOF

#----------------------------------------
