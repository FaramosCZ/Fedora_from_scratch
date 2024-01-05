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

# When BIOS is used, we need to create BIOS BOOT partition at the beginning of the disk
#   1 MB is the usual size
partition_bios=";1M;21686148-6449-6E6F-744E-656564454649;"

# The only other thing on the disk will be a single BTRFS partition covering the rest of the space
# When size is set bigger than what the real disk size is, maximum left disk space is used instead
partition_btrfs=";99T;;"

# Execute the 'sfdisk' utility
sfdisk_input=f"{partition_bios}\n{partition_btrfs}"
shell_cmd(f'echo "{sfdisk_input}" | sfdisk {disk_path}')

#----------------------------------------
# CREATE FILESYSTEMS

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

fstab_entry=f'''\
LABEL=BTRFS-{random_hash}  /           btrfs  noatime,subvol=boot  0  0
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
repofile = f'''\
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

common_dnf_arguments = f'--releasever="{fedora_release}" --installroot={mountpoint_path} -y --nogpgcheck'

custom_core_packages = 'nano tree bash-completion git wget'
custom_kernel_packages = 'kernel kernel-core kernel-modules -x amd-gpu-firmware -x nvidia-gpu-firmware'

shell_cmd(f'dnf --comment="Install the DNF group @core" {common_dnf_arguments} --repo="fedora-custom" install btrfs-progs langpacks-en langpacks-cs glibc-all-langpacks @core')

# Save the actual fstab
with open(f'{mountpoint_path}/etc/fstab', 'w') as file:
    file.write(fstab_entry)

# Install the favourite software inside
# NOTE: DNF will prioritize the configuration inside "--installroot", so we don't need to use our custom repo anymore.
#       If we would like to use the Host system repo instead, we would need to use "--setopt=reposdir=..." to force repos on Host to be priotitized.
shell_cmd(f'dnf --comment="Install custom packages which I want to be part of the minimal installation" {common_dnf_arguments} install {custom_core_packages}')

# Make sure the kernel was installed too
# MAYBE BUG: sometimes (e.g. when installing Fedora Beta release), the kernel won't install ... why? That's mystery. Let's make sure we have it.
shell_cmd(f'dnf --comment="Install kernel" {common_dnf_arguments} install {custom_kernel_packages}')

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
shell_cmd(f'dnf --comment="Install GRUB" {common_dnf_arguments} install grub2-pc-modules')

# Put the custom GRUB configuration to the /boot/grub2/grub.cfg path and protect it
shell_cmd(f'cp -f "./GRUB_BTRFS/grub.cfg" {mountpoint_path}/boot/grub2/grub.cfg')
shell_cmd(f'sed -i "s/REPLACE-THIS-WITH-DISK-LABEL/BTRFS-{random_hash}/g" {mountpoint_path}/boot/grub2/grub.cfg')
shell_cmd(f'chattr +i {mountpoint_path}/boot/grub2/grub.cfg')

# Disable *all* of the default GRUB configuration
shell_cmd(f'chmod -x {mountpoint_path}/etc/grub.d/*')

# The 'kernel-core' package calls in its post-trans scriptlet the
# 'kernel-install' script, which reads the
# '/usr/lib/kernel/install.d/90-loadentry.install' script which reads the
# '/etc/kernel/cmdline' config file
kernel_parameters=f"root=LABEL=BTRFS-{random_hash} rootflags=subvol=boot ro"
extra_kernel_parameters=" "
shell_cmd(f'echo {kernel_parameters} {extra_kernel_parameters} > {mountpoint_path}/etc/kernel/cmdline')
shell_cmd(f'chattr +i {mountpoint_path}/etc/kernel/cmdline')

# But also, it calls *somehow* the
# '/sbin/grub2-get-kernel-settings' which calls the
# '/usr/share/grub/grub-mkconfig' which calls the
# '/usr/bin/grub2-mkrelpath' in order to find the full path to the kernel from GRUB POV - that means also the name of the BTRFS subvolume
# However we need the subvolume to be always the
# 'boot' so the bootloader entry would work for any name of the BTRFS subvolume it reside in
shell_cmd(f'mv {mountpoint_path}/usr/bin/grub2-mkrelpath {mountpoint_path}/usr/bin/grub2-mkrelpath-ORIGINAL')
file_content = f'''\
#! /usr/bin/bash
# This script is a wrapper on top of the GRUB grub2-mkrelpath binary,
# It fixes an issue with BTRFS subvolume probe.
# Instead of taking the found subvolume, force our own instead
echo "/boot"$(/usr/bin/grub2-mkrelpath-ORIGINAL -r "$1")
'''
with open(f'{mountpoint_path}/usr/bin/grub2-mkrelpath', 'w') as file:
    file.write(file_content)

shell_cmd(f'chmod a+x {mountpoint_path}/usr/bin/grub2-mkrelpath')

# Fortify against package updates
shell_cmd(f'chattr +i {mountpoint_path}/usr/bin/grub2-mkrelpath')
shell_cmd(f'chattr +i {mountpoint_path}/usr/bin/grub2-mkrelpath-ORIGINAL')

file_content = f'''\
# All GRUB package updates must be revieved by hand to check whether they break workaround with /usr/bin/grub2-mkrelpath wrapper
grub2-tools
'''
with open(f'{mountpoint_path}/etc/dnf/protected.d/CUSTOM-grub2.conf', 'w') as file:
    file.write(file_content)

# Re-install the kernel-core to re-generate the BLS boot entries
shell_cmd(f'dnf --comment="Reinstall kernel-core to re-generate the GRUB boot entries" {common_dnf_arguments} reinstall kernel-core')

# However since the kernel-core re-instal doesn't do it's job for the RESCUE entry, we have to fix it manually
shell_cmd(f'sed -i "s|^options .*|options $(cat {mountpoint_path}/etc/kernel/cmdline) |g" {mountpoint_path}/boot/loader/entries/*rescue.conf')
shell_cmd(f'sed -i "s| /root/boot/| /boot/boot/|g" {mountpoint_path}/boot/loader/entries/*rescue.conf')

# Install the GRUB onto the disk
#   for BIOS boot it is necessary to install the grub manually to the disk
#   this will also create directories under /boot/grub2 containing necessary GRUB modules
shell_cmd(f'echo "grub2-install --target=i386-pc {disk_path}" | chroot {mountpoint_path} /bin/bash')

#----------------------------------------
#----------------------------------------
#----------------------------------------
#----------------------------------------

# Update all packages to the latest version
shell_cmd(f'dnf --comment="Update all packages" {common_dnf_arguments} update')

# Restore the correct SELinux labeling on the target system
shell_cmd(f'echo -e "setfiles -F /etc/selinux/targeted/contexts/files/file_contexts /" | chroot {mountpoint_path} /bin/bash', ignore_error_code=True)

# Set the initial root password
shell_cmd(f'echo -e "root:root" | chpasswd --root {mountpoint_path}/')

# Copy this script repo inside
shell_cmd(f'cp -a ./../ {mountpoint_path}/root/fedora_from_scratch')
