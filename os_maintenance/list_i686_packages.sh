#!/bin/bash

#----------------------------------------
# List all installed 32-bit (i686) packages

rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | grep '\.i686$' | sort

#----------------------------------------
