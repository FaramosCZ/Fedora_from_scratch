#!/bin/bash

#----------------------------------------
# Diff installed packages between two BTRFS snapshots
#
# Usage: ./diff_packages.sh SNAPSHOT_A SNAPSHOT_B
# Snapshots can be snapshot names or "boot" to use the active system

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SNAPSHOT_A SNAPSHOT_B" >&2
    echo "Example: $0 RO-BACKUP-01-minimal_headless_server_setup_finished RO-BACKUP-02-GUI_setup_finished" >&2
    echo "Use \"boot\" for the currently running system" >&2
    exit 1
fi

mount --target=/mnt/BTRFS-ROOT 2>/dev/null

resolve_snapshot() {
    local name="$1"
    local path="/mnt/BTRFS-ROOT/$name"

    if [[ ! -e "$path" ]]; then
        echo "ERROR: Snapshot not found: $name" >&2
        echo "Available:" >&2
        ls -1 /mnt/BTRFS-ROOT/ >&2
        exit 1
    fi

    if [[ -L "$path" ]]; then
        local target
        target=$(readlink -f "$path")
        if [[ ! -d "$target" ]]; then
            echo "ERROR: Symlink '$name' points to non-existent target: $target" >&2
            exit 1
        fi
        path="$target"
    fi

    echo "$path"
}

SNAP_A=$(resolve_snapshot "$1") || exit 1
SNAP_B=$(resolve_snapshot "$2") || exit 1

PKGS_A=$(rpm --root="$SNAP_A" -qa --qf '%{NAME}.%{ARCH}\n' | sort)
PKGS_B=$(rpm --root="$SNAP_B" -qa --qf '%{NAME}.%{ARCH}\n' | sort)

echo "=== Only in $1 ==="
comm -23 <(echo "$PKGS_A") <(echo "$PKGS_B")

echo ""
echo "=== Only in $2 ==="
comm -13 <(echo "$PKGS_A") <(echo "$PKGS_B")

#----------------------------------------
