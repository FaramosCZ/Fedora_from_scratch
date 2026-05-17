#!/bin/bash

#----------------------------------------
# Run BTRFS balance on the root filesystem

echo "=== Before ==="
btrfs filesystem usage /

echo ""
echo "=== Balancing ==="
btrfs balance start -dusage=75 -musage=75 /

echo ""
echo "=== After ==="
btrfs filesystem usage /

#----------------------------------------
