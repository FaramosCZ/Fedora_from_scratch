#!/bin/bash

#----------------------------------------
# Show differences between two BTRFS snapshots
#
# Usage: ./diff_snapshots.sh SNAPSHOT_A SNAPSHOT_B

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SNAPSHOT_A SNAPSHOT_B" >&2
    echo "Example: $0 RO-BACKUP-01-minimal_headless_server_setup_finished RO-BACKUP-02-GUI_setup_finished" >&2
    exit 1
fi

mount --target=/mnt/BTRFS-ROOT 2>/dev/null

SNAP_A="/mnt/BTRFS-ROOT/$1"
SNAP_B="/mnt/BTRFS-ROOT/$2"

if [[ ! -d "$SNAP_A" ]]; then
    echo "ERROR: Snapshot not found: $1" >&2
    exit 1
fi

if [[ ! -d "$SNAP_B" ]]; then
    echo "ERROR: Snapshot not found: $2" >&2
    exit 1
fi

echo "=== Changes from $1 to $2 ==="
btrfs send --no-data -p "$SNAP_A" "$SNAP_B" | btrfs receive --dump

#----------------------------------------
