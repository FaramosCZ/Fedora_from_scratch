#!/bin/bash

#----------------------------------------
# Disable ssh daemon by default

systemctl disable sshd || true

#----------------------------------------
