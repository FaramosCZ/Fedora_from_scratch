#!/bin/bash

#----------------------------------------
# Display the current LAN IP address before the login prompts on TUI TTYs

#!/bin/bash

# Prompt the user for input
echo "Set this machine HOSTNAME: "
read new_hostname

echo "$new_hostname" > /etc/hostname

#----------------------------------------
