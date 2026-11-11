fedora_release=45

# "fresh"    = full install from Live USB (wipes disk, creates partitions and filesystems)
# "sideload" = install alongside existing system (reuses disk layout, GRUB chain, and labels)
install_mode = "fresh"

# Needed for cleanup.py
mountpoint_path = "/mnt/FEDORA_FROM_SCRATCH"

# --- Fresh mode settings ---
disk = "sda"
device_name="FEDORA-FROM-SCRATCH"
disk_path = f"/dev/{disk}"

# --- Sideload mode settings ---
new_subvolume = "root-f45"
