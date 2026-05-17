#!/bin/bash

#----------------------------------------
# Clean up system logs and caches

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Must be run as root" >&2
    exit 1
fi

BEFORE=$(df --output=avail / | tail -1)

echo "=== Journal ==="
journalctl --disk-usage
journalctl --vacuum-size=50M

echo ""
echo "=== Audit logs ==="
du -sh /var/log/audit/ 2>/dev/null
find /var/log/audit/ -name "audit.log.*" -delete 2>/dev/null
echo "Rotated audit logs removed"

echo ""
echo "=== Coredumps ==="
du -sh /var/lib/systemd/coredump/ 2>/dev/null
rm -rf /var/lib/systemd/coredump/*
echo "Coredumps removed"

echo ""
echo "=== ABRT spool ==="
du -sh /var/spool/abrt/ 2>/dev/null
rm -rf /var/spool/abrt/*
echo "ABRT spool removed"

echo ""
echo "=== DNF cache ==="
dnf clean all

AFTER=$(df --output=avail / | tail -1)
FREED=$(( (AFTER - BEFORE) * 1024 ))

echo ""
echo "=== Total space freed: $(numfmt --to=iec "$FREED") ==="

#----------------------------------------
