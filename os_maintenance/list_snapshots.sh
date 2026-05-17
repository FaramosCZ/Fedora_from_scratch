#!/bin/bash

#----------------------------------------
# List BTRFS snapshots and show active subvolume

mount --target=/mnt/BTRFS-ROOT 2>/dev/null

echo "=== Active subvolume ==="
readlink /mnt/BTRFS-ROOT/boot

echo ""
echo "=== Subvolumes ==="
btrfs subvolume list /mnt/BTRFS-ROOT

echo ""
echo "=== Directory listing ==="
ls -la /mnt/BTRFS-ROOT/

#----------------------------------------
