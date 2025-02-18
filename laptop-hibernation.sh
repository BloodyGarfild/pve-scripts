#!/bin/bash
export LANG=en_US.UTF-8

# Import Colors
source <(curl -s https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/misc/colors.sh)
source <(curl -s https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/misc/emojis.sh)

# Clearing screen
clear

# Post message
echo""
echo -e "${C}+++++++++++++++++++++++++++++++++++++++++++++++++++++++${X}"
echo -e "${C}+++++++++++++++++ Laptop-Hibernation ++++++++++++++++++${X}"
echo -e "${C}+++++++++++++++++++++++++++++++++++++++++++++++++++++++${X}"
echo""

# Ask for continue script
echo -e "${Y}This script will add the required lines into${X}"
echo "-----"
echo -e "${R}'/etc/systemd/logind.conf'${X}"
echo "-----"
echo -e "${Y}to use a laptop as an PVE host${X}"
echo ""
echo -e "${Y}Run script now? (y/N)${X}"
read run_script
echo ""

if [[ "$run_script" =~ ^[Yy]$ ]]; then
		echo -e "${G}Running...${X}"
    else
		echo -e "${R}Stopping...${X}"
		exit 1
fi

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "${R}⚠️ This script must be run as root!${X}"
    exit 1
fi

echo -e "${G}Configuring Proxmox for laptop usage...${X}"

# Disable hibernation and suspend when closing the lid
echo -e "${Y}Disabling hibernation and suspend on lid close...${X}"

CONFIG_FILE="/etc/systemd/logind.conf"

# Backup the original configuration file
cp $CONFIG_FILE ${CONFIG_FILE}.bak

# Remove existing lid switch settings
sed -i '/^HandleLidSwitch=/d' $CONFIG_FILE
sed -i '/^HandleLidSwitchExternalPower=/d' $CONFIG_FILE
sed -i '/^HandleLidSwitchDocked=/d' $CONFIG_FILE

# Apply new settings
echo "HandleLidSwitch=ignore" >> $CONFIG_FILE
echo "HandleLidSwitchExternalPower=ignore" >> $CONFIG_FILE
echo "HandleLidSwitchDocked=ignore" >> $CONFIG_FILE

# Restart systemd-logind to apply changes
systemctl restart systemd-logind

echo -e "${G}✅ Proxmox laptop configuration completed!${X}"
