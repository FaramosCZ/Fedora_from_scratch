#!/bin/bash

#----------------------------------------
# Limit systemd journal size to 50 MB
#   I usually need only the log from the current boot, or the previous one.
#   I've never had any use for keeping gigabytes of logs around.
#   IMO that only makes sense for long-running systems, servers, etc.
#   The 50 MB is an arbitrary value I've came up with. Let's see if i will be fine.
#
#   https://andreaskaris.github.io/blog/linux/setting-journalctl-limits/

sed -i 's|#SystemMaxUse=|SystemMaxUse=50M|g' /etc/systemd/journald.conf
systemctl restart systemd-journald

#----------------------------------------
