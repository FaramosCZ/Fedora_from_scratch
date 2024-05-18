#! /usr/bin/python3

import subprocess
from sys import exit

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
