#!/bin/bash

#----------------------------------------
# Automatic Btrfs snapshot before every DNF transaction
#   Uses libdnf5-plugin-actions to run a script on pre_transaction.
#   Creates a read-only snapshot of the active root subvolume (via the
#   "boot" symlink), and prunes old auto-snapshots beyond retention limit.
#   Only auto-snapshots are pruned — manual RO-BACKUP-NN-* are never touched.

dnf install -y libdnf5-plugin-actions

mkdir -p /etc/dnf/libdnf5-plugins/actions.d

cat << 'EOF' > /etc/dnf/libdnf5-plugins/actions.d/btrfs-snapshot.actions
pre_transaction::::/usr/local/bin/dnf-pre-snapshot.sh
EOF

cat << 'EOF' > /usr/local/bin/dnf-pre-snapshot.sh
#!/bin/bash
set -euo pipefail

BTRFS_MOUNT="/mnt/BTRFS-ROOT"
ACTIVE_SUBVOL="boot"
PREFIX="RO-BACKUP-auto"
MAX_AUTO_SNAPSHOTS=10
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAP_NAME="${PREFIX}-${TIMESTAMP}"

mounted_here=false

if ! mountpoint -q "$BTRFS_MOUNT"; then
    mount "$BTRFS_MOUNT" || exit 1
    mounted_here=true
fi

cleanup() {
    if $mounted_here; then
        umount "$BTRFS_MOUNT" 2>/dev/null || true
    fi
}
trap cleanup EXIT

if [ ! -d "${BTRFS_MOUNT}/${ACTIVE_SUBVOL}" ]; then
    echo "dnf-pre-snapshot: active subvolume '${ACTIVE_SUBVOL}' not found" >&2
    exit 1
fi

btrfs subvolume snapshot -r \
    "${BTRFS_MOUNT}/${ACTIVE_SUBVOL}" \
    "${BTRFS_MOUNT}/${SNAP_NAME}"

mapfile -t old_snaps < <(
    find "$BTRFS_MOUNT" -maxdepth 1 -name "${PREFIX}-*" -printf '%f\n' | sort
)

while [ "${#old_snaps[@]}" -gt "$MAX_AUTO_SNAPSHOTS" ]; do
    oldest="${old_snaps[0]}"
    btrfs subvolume delete "${BTRFS_MOUNT}/${oldest}" >/dev/null 2>&1 || true
    old_snaps=("${old_snaps[@]:1}")
done

echo "dnf-pre-snapshot: created ${SNAP_NAME} (${#old_snaps[@]}/${MAX_AUTO_SNAPSHOTS} auto-snapshots kept)"
EOF

chmod 755 /usr/local/bin/dnf-pre-snapshot.sh

#----------------------------------------
