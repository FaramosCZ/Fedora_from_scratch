#! /usr/bin/python3

import subprocess
from sys import exit

from os import geteuid

# =================================================================================================================

# Check if the script is run with root privileges
if geteuid() == 0:
    print("\033[1;32mRUNNING AS ROOT\033[0m")
else:
    print("\033[1;31mERROR: THIS SCRIPT HAS TO BE EXECUTED AS ROOT !\033[0m")
    exit(1)

# =================================================================================================================

def shell_cmd(command, print_stdout=True, print_command=True, ignore_error_code=False):

    if print_command:
        print(f"\033[1m\nCMD:\n{command}\n\033[0m")

    # Run the command with shell=True and print output directly
    process = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

    if print_stdout:
        print(f"CMD OUTPUT:\n{process.stdout}")

    # Check the return code
    if not ignore_error_code:
        if process.returncode != 0:
            print("\033[1;31mCOMMAND FAILED with return code:\033[0m", process.returncode)
            exit(process.returncode)

# =================================================================================================================
