#!/bin/bash

#----------------------------------------
# Search for files protected with the immutable bit (chattr +i)

find / -xdev -exec lsattr -d {} + 2>/dev/null | grep '^[^ ]*i'

#----------------------------------------
