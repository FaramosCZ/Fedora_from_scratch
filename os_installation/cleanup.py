#! /usr/bin/python3

from config import *
from lib import *

#----------------------------------------
# Make sure all partitions are unmounted

shell_cmd('swapoff -a', ignore_error_code=True)
shell_cmd(f'swapoff {disk_path}*', ignore_error_code=True)
shell_cmd(f'umount -l {disk_path}*', ignore_error_code=True)
shell_cmd(f'umount -R -c {mountpoint_path}/*', ignore_error_code=True)
shell_cmd(f'umount -l /dev/mapper/decrypted_boot', ignore_error_code=True)
shell_cmd(f'umount -R -c /dev/mapper/decrypted_boot', ignore_error_code=True)
shell_cmd(f'cryptsetup close decrypted_boot', ignore_error_code=True)
shell_cmd('sync ; sleep 3', False, False, True)

#----------------------------------------
