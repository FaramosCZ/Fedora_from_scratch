#! /usr/bin/python3

import subprocess
from sys import exit

from random import choices
from string import ascii_lowercase, digits

from os import geteuid

# =================================================================================================================

# Check if the script is run with root privileges
if geteuid() == 0:
    print("RUNNING AS ROOT")
else:
    print("ERROR: THIS SCRIPT HAS TO BE EXECUTED AS ROOT !")
    exit(1)

# =================================================================================================================

def shell_cmd(command, print_stdout=True, print_command=True, ignore_error_code=False):

    if print_command:
        print(f"\nCMD:\n{command}\n")

    # Run the command with shell=True and print output directly
    process = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    if print_stdout:
        print(f"CMD OUTPUT:\n{process.stdout}")

    # Check the return code
    if not ignore_error_code:
        if process.returncode != 0:
            print("COMMAND FAILED with return code:", process.returncode)
            exit(process.returncode)

# =================================================================================================================

disk = "sda"
disk_path = f"/dev/{disk}"
mountpoint_path = "/mnt/FEDORA_FROM_SCRATCH"

partition_path = []
if disk.startswith(("sd", "hd", "xvd")):
    partition_char = ""
elif disk.startswith(("nvme", "vd", "mmcblk")):
    partition_char = "p"

partition_path = { 1: f"{disk_path}{partition_char}1", 2: f"{disk_path}{partition_char}2"}

# Generate a random 6-character string
random_hash = ''.join(choices(ascii_lowercase + digits, k=6))

fedora_release=39

device_name="PY-fed-FARAMOS"

#----------------------------------------

# Make sure we have all of the required software
#   All of the 'sfdisk', 'mkfs' and 'mount' utilities lives in the 'util-linux' package
#   The 'readlink' utility is in the 'coreutils' package
#   The 'btrfs-progs' obviously for tools for working with BTRFS
#   The 'dosfstools' offers the 'mkfs.vfat' required for creating an EFI parition filesystem
shell_cmd("dnf install -y util-linux coreutils btrfs-progs dosfstools")

#----------------------------------------
# PREPARE THE DISK LAYOUT

# Make sure all partitions are unmounted
shell_cmd('swapoff -a', ignore_error_code=True)
shell_cmd(f'swapoff {disk_path}*', ignore_error_code=True)
shell_cmd(f'umount -l {disk_path}*', ignore_error_code=True)
shell_cmd(f'umount -R -c {mountpoint_path}/*', ignore_error_code=True)
shell_cmd('sync ; sleep 3', False, False, True)

#----------------------------------------
# CREATE PARTITIONS

# Create modern GPT layout of the partition tables
shell_cmd(f'echo "label: gpt" | sfdisk {disk_path}')
shell_cmd('sync ; sleep 1', False, False, True)

# When UEFI is used, we need to create EFI partition at the beginning of the disk
#   50 MB should be more than enough in case of Fedora. The required space depends mainly
#   on the bootloader and its choice which data to store on EFI and which elsewhere.
partition_efi=";50M;C12A7328-F81F-11D2-BA4B-00A0C93EC93B;"

# The only other thing on the disk will be a single BTRFS partition covering the rest of the space
# When size is set bigger than what the real disk size is, maximum left disk space is used instead
partition_btrfs=";99T;;"

# Execute the 'sfdisk' utility
sfdisk_input=f"{partition_efi}\n{partition_btrfs}"
shell_cmd(f'echo "{sfdisk_input}" | sfdisk {disk_path}')

#----------------------------------------
# CREATE FILESYSTEMS

# Create filesystem on the EFI partition
#   use 'a' to overwrite any FS that was present
shell_cmd(f'echo a | mkfs.vfat -n "EFI-{random_hash}" {partition_path[1]}')

# Create filesystem on the BTRFS partition
#   use 'a' to overwrite any FS that was present
shell_cmd(f'echo a | mkfs.btrfs -f -L "BTRFS-{random_hash}" {partition_path[2]}')

#----------------------------------------
#----------------------------------------
#----------------------------------------
#----------------------------------------

# Prepare the mount directory
shell_cmd(f'mkdir -p {mountpoint_path}')

# Mount the root of the BTRFS there
shell_cmd(f'mount -t btrfs {partition_path[2]} {mountpoint_path}')
# Create a subvolume that will act as a root for our filesystem
shell_cmd(f'btrfs subvolume create {mountpoint_path}/root')
# Also create a symlink to it, which will be used by GRUB EFI confiuration
shell_cmd(f'cd {mountpoint_path} ; ln -s "root" "boot"')
# Mount the new subvolume instead
shell_cmd(f'umount {mountpoint_path}')
shell_cmd(f'mount -t btrfs -o subvol="boot" {partition_path[2]} {mountpoint_path}')

# Create a directory for EFI partition mount point
shell_cmd(f'mkdir -p {mountpoint_path}/boot/efi/')
# And mount the EFI partition inside
shell_cmd(f'mount {partition_path[1]} {mountpoint_path}/boot/efi/')

fstab_entry=f'''\
LABEL=EFI-{random_hash}    /boot/efi/  vfat   defaults     0  2
LABEL=BTRFS-{random_hash}  /           btrfs  subvol=boot  0  0
'''

# Mount the rest of the directories from the running system
# Mount before installing anything since many scriptlets assume existence of /dev/*
shell_cmd(f'mkdir {mountpoint_path}/sys {mountpoint_path}/proc {mountpoint_path}/dev ')

# To fix the bug in SELinux labeling rhbz#1467103 rhbz#1714026
shell_cmd(f'chcon --reference=/dev {mountpoint_path}/dev ')

shell_cmd(f'mount -t sysfs none {mountpoint_path}/sys ')
shell_cmd(f'mount -t proc  none {mountpoint_path}/proc ')
shell_cmd(f'mount -o bind  /dev {mountpoint_path}/dev ')

#----------------------------------------
#----------------------------------------
#----------------------------------------
#----------------------------------------

# Don't assume the OS version we are currently in. Prepare custom repository to get packages from.
repofile = f'''
[fedora-custom]
name=fedora-custom
enabled=1
gpgcheck=0
metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-{fedora_release}&arch=x86_64
'''
with open('/etc/yum.repos.d/fedora-custom.repo', 'w') as file:
    file.write(repofile)

#----------------------------------------

# Install core software inside the mounted directory tree
# NOTE:
#   the 'btrfs-progs' package is needed for installation scriplets of the 'grub2-common' and 'kernel-core' packages
# NOTE:
#   The 'glibc-all-langpacks' is needed before we set preferred locale and keyboard layout
#   The 'langpacks-en' and 'langpacks-cs' are required in oder to anythying to look "pretty". Or in some cases readable at all. For example text in the 'terminator' program in GUI.

common_dnf_arguments = f'--releasever="{fedora_release}" -y --nogpgcheck'

custom_core_packages = 'nano tree bash-completion git wget'
custom_kernel_packages = 'kernel kernel-core kernel-modules -x amd-gpu-firmware -x nvidia-gpu-firmware'

shell_cmd(f'dnf --comment="Install the DNF group @core" --installroot={mountpoint_path} {common_dnf_arguments} --repo="fedora-custom" install btrfs-progs langpacks-en langpacks-cs glibc-all-langpacks @core')

# Save the actual fstab
with open(f'{mountpoint_path}/etc/fstab', 'w') as file:
    file.write(fstab_entry)

# Install the favourite software inside
# NOTE: DNF will prioritize the configuration inside "--installroot", so we don't need to use our custom repo anymore.
#       If we would like to use the Host system repo instead, we would need to use "--setopt=reposdir=..." to force repos on Host to be priotitized.
shell_cmd(f'echo -e "dnf --comment="Install custom packages which I want to be part of the minimal installation" {common_dnf_arguments} install {custom_core_packages}" | chroot {mountpoint_path} /bin/bash')

# Make sure the kernel was installed too
# MAYBE BUG: sometimes (e.g. when installing Fedora Beta release), the kernel won't install ... why? That's mystery. Let's make sure we have it.
shell_cmd(f'echo -e "dnf --comment="Install kernel" {common_dnf_arguments} install {custom_kernel_packages}" | chroot {mountpoint_path} /bin/bash')

#----------------------------------------

# Copy network resolution file into the mounted system
shell_cmd(f'echo y | cp --remove-destination /etc/resolv.conf {mountpoint_path}/etc/ ')

# Set up device name
shell_cmd(f'echo {device_name} > {mountpoint_path}/etc/hostname')

#----------------------------------------
#----------------------------------------
#----------------------------------------
#----------------------------------------

# Copy /etc/default/grub config file inside
shell_cmd(f'echo y | cp --remove-destination ./GRUB_BTRFS/etc-default-grub {mountpoint_path}/etc/default/grub ')

# Install GRUB
shell_cmd(f'echo -e "dnf --comment="Install GRUB" {common_dnf_arguments} install grub2-efi-x64 grub2-efi-x64-modules shim" | chroot {mountpoint_path} /bin/bash')

# Copy /etc/default/grub config file inside
shell_cmd(f'echo y | cp --remove-destination ./GRUB_BTRFS/EFI-grub.cfg {mountpoint_path}/boot/efi/EFI/fedora/grub.cfg ')
shell_cmd(f'sed -i "s/REPLACE-THIS-WITH-DISK-LABEL/BTRFS-{random_hash}/g" {mountpoint_path}/boot/efi/EFI/fedora/grub.cfg ')

# Disable the default GRUB configuration
shell_cmd(f'chmod -x {mountpoint_path}/etc/grub.d/*')
# Insert the custom GRUB configuration
shell_cmd(f'cp -f "./GRUB_BTRFS/grub.cfg" {mountpoint_path}/etc/grub.d/custom-grub.cfg')
shell_cmd(f'chmod +x {mountpoint_path}/etc/grub.d/custom-grub.cfg')
shell_cmd(f'sed -i "s/REPLACE-THIS-WITH-DISK-LABEL/BTRFS-{random_hash}/g" {mountpoint_path}/etc/grub.d/custom-grub.cfg ')

# Generate the GRUB config inside of the chroot
shell_cmd(f'echo "grub2-mkconfig -o /boot/grub2/grub.cfg" | chroot {mountpoint_path} /bin/bash')

# Update all packages to the latest version
shell_cmd(f'echo -e "dnf --comment="Update all packages" {common_dnf_arguments} update" | chroot {mountpoint_path} /bin/bash')

# Make sure the kernel was installed; reinstall it to re-generate the GRUB boot entries
shell_cmd(f'echo -e "dnf --comment="Reinstall kernel to re-generate the GRUB boot entries" {common_dnf_arguments} reinstall {custom_kernel_packages}" | chroot {mountpoint_path} /bin/bash')

# Restore the correct SELinux labeling on the target system
shell_cmd(f'echo -e "setfiles -F /etc/selinux/targeted/contexts/files/file_contexts /" | chroot {mountpoint_path} /bin/bash', ignore_error_code=True)

# Set the initial root password
shell_cmd(f'echo -e "root:root" | chpasswd --root {mountpoint_path}/')

# Fix final version of bootloader entries after they were re-generated be kernel re-installation
shell_cmd(f'sed -i "s|^options .*|options root=LABEL=BTRFS-{random_hash} rootflags=subvol=boot |g" {mountpoint_path}/boot/loader/entries/* ')

# Copy this script repo inside
shell_cmd(f'cp -a ./../ {mountpoint_path}/root/fedora_from_scratch')
#cp -a ./../ "$MOUNTPOINT"/root/fedora_from_scratch
#

