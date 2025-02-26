#!/bin/bash

# Script Name: vdsm-arc-disk-update.sh
# Author: And-rix (https://github.com/And-rix)
# Version: v1.0
# Creation: 26.02.2025
# Modified: 26.02.2025 (v1.0)

export LANG=en_US.UTF-8

# Import Misc
source <(curl -s https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/misc/colors.sh)
source <(curl -s https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/misc/emojis.sh)

# Clearing screen
clear

# Post message
echo ""
echo -e "${C}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++${X}"
echo -e "${C}++++++++++++++++ vDSM-Arc-Disk-Update +++++++++++++++++++${X}"
echo -e "${C}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++${X}"
echo ""

# Continue Script?
echo -e "${Y}${INFO}This tool can only update an existing VM.${X}"
echo "-----"
echo -e "${C}1: Virtual disk - Add more virtual Disks to vDSM.Arc${X}"
echo -e "${C}2: Physical disk - Show the command to paste in PVE shell${X}"
echo "-----"
echo ""
echo -e "${Y}${INFO}Run script now? (y/Y)${X}"
read run_script
echo ""

if [[ "$run_script" =~ ^[Yy]$ ]]; then
    echo -e "${G}${OK}Running...${X}"
    echo ""
    echo ""
else
    echo -e "${R}${NOTOK}Stopping...${X}"
    echo ""
    exit 1
fi

# Function to check if a VM exists
CHECK_VM_EXISTS() {
    qm list | awk 'NR>1 {print $1}' | grep -q "^$1$"
}

# Function to list all VMs
LIST_ALL_VMS() {
    qm list | awk 'NR>1 {print $2" - ID: "$1}'
}

while true; do
    # Display list of all VMs
    echo ""
    echo -e "${C}List of all VMs:${X}"
    echo "-------------------------"
    LIST_ALL_VMS
    echo "-------------------------"
    echo ""

    # Ask for VM ID
    echo -e "${C}Please enter the VM ID (example: 101): ${X}"
    read -r VM_ID

    # Check VM exists
    if CHECK_VM_EXISTS "$VM_ID"; then
        echo ""
        echo -e "${G}${OK}The VM with ID $VM_ID exists. Starting precheck...${X}"
        break
    else
        echo ""
        echo -e "${R}${NOTOK}The VM with ID $VM_ID does not exist. Please try again.${X}"
    fi
done

# Selection menu / Precheck
while true; do
	# Function available SATA port
	precheck_sata_port() {
		for PORT in {1..5}; do
			if ! qm config $VM_ID | grep -q "sata$PORT"; then
				echo "sata$PORT"
				return
			fi
		done
		echo ""  
	}

	# Check available SATA port before proceeding
	PRE_SATA_PORT=$(precheck_sata_port)

	if [[ -z "$PRE_SATA_PORT" ]]; then
		echo ""
		echo -e "${R}${NOTOK}No available SATA ports between SATA1 and SATA5. Exiting...${X}"
		exit 1  
	fi
	
    echo ""
    echo -e "${Y}${DISK} Choose your option:${X}"
    echo -e "${C}a) Create Virtual Hard Disk${X}"
    echo -e "${C}b) Show Physical Hard Disk${X}"
    echo -e "${R}c) Exit${X}"
    read -n 1 option

    case "$option" in
        a) #Virtual Disk
			echo -e "${C}${TAB}Create Virtual Hard Disk${X}"
			echo ""
			
			# Storage locations > Disk images
			VM_DISKS=$(pvesm status -content images | awk 'NR>1 {print $1}')

			# Check availability
			if [ -z "$VM_DISKS" ]; then
			  echo -e "${R}No storage locations found that support disk images.${X}"
			  continue
			fi

			# Display storage options
			echo -e "${Y}Available target location for Virtual Disk:${X}"
			select VM_DISK in $VM_DISKS "Exit"; do
			  if [ "$VM_DISK" == "Exit" ]; then
				echo -e "${G}${OK}Back 2 Menu...${X}"
				continue 2
			  elif [ -n "$VM_DISK" ]; then
				echo -e "${G}You have selected: $VM_DISK${X}"
				break
			  else
				echo -e "${R}Invalid selection. Please try again.${X}"
			  fi
			done

			
			# Next available SATA-Port
			find_available_sata_port() {
			  for PORT in {1..5}; do
				if ! qm config $VM_ID | grep -q "sata$PORT"; then
				  echo "sata$PORT"
				  return
				fi
			  done
			  echo -e "${R}No available SATA ports between SATA1 and SATA5${X}"
			}

			# Check Storage type
			VM_DISK_TYPE=$(pvesm status | awk -v s="$VM_DISK" '$1 == s {print $2}')
			echo "Storage type: $VM_DISK_TYPE"

			# Ask for disk size (at least 32 GB)
			read -p "Enter the disk size in GB (minimum 32 GB): " DISK_SIZE

			if [[ ! "$DISK_SIZE" =~ ^[0-9]+$ ]] || [ "$DISK_SIZE" -lt 32 ]; then
			  echo -e "${R}Invalid input. The disk size must be a number and at least 32 GB.${X}"
			  continue
			fi

			SATA_PORT=$(find_available_sata_port)
			DISK_NAME="vm-$VM_ID-disk-$SATA_PORT"

			# Generate disk path > block/file based
			if [[ "$VM_DISK_TYPE" == "dir" || "$VM_DISK_TYPE" == "nfs" || "$VM_DISK_TYPE" == "cifs" || "$VM_DISK_TYPE" == "btrfs" ]]; then 
			  DISK_PATH="$VM_DISK:$DISK_SIZE,format=qcow2"  # Path for dir, nfs, cifs, btrfs
			  sleep 1
			  qm set "$VM_ID" -$SATA_PORT "$DISK_PATH",backup=0
			else
			  DISK_PATH="$VM_DISK:$DISK_SIZE"  # Path for lvmthin, zfspool,..
			  sleep 1
			  qm set "$VM_ID" -$SATA_PORT "$DISK_PATH",backup=0
			fi
			
			echo ""
			echo -e "${G}${OK}Disk created and assigned to $SATA_PORT: $DISK_PATH ${X}"
			;;
		b) #Physical Disk
			echo -e "${C}${TAB}Show Physical Hard Disk${X}"
			echo ""
			
			# Next available SATA-Port
			find_available_sata_port() {
			  for PORT in {1..5}; do
				if ! qm config $VM_ID | grep -q "sata$PORT"; then
				  echo "sata$PORT"
				  return
				fi
			  done
			  echo -e "${R}No available SATA ports between SATA1 and SATA5${X}"
			}
			
			SATA_PORT=$(find_available_sata_port)
			DISKS=$(find /dev/disk/by-id/ -type l -print0 | xargs -0 ls -l | grep -v -E '[0-9]$' | awk -F' -> ' '{print $1}' | awk -F'/by-id/' '{print $2}')
			DISK_ARRAY=($(echo "$DISKS"))

			# Display the disk options with numbers
			echo -e "${Y}Select a physical disk:${X}"
			for i in "${!DISK_ARRAY[@]}"; do
			  echo "$((i + 1))) ${DISK_ARRAY[i]}"
			done
			echo "0) Exit"

			read -p "#? " SELECTION

			# Input check
			if ! [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
			  echo ""
			  echo -e "${Y}${WARN}Invalid input. Please enter a number.${X}"
			  continue 2
			fi

			# Validating
			if [[ "$SELECTION" -eq 0 ]]; then
			  echo ""
			  echo -e "${G}${OK}Back 2 Menu...${X}"
			  continue 2
			elif [[ "$SELECTION" -ge 1 && "$SELECTION" -le "${#DISK_ARRAY[@]}" ]]; then
			  SELECTED_DISK="${DISK_ARRAY[$((SELECTION - 1))]}"
			else
			  echo ""
			  echo -e "${Y}${WARN}Invalid selection.${X}"
			  continue 2
			fi
			
			echo ""
				echo -e "${Y}You have selected $SELECTED_DISK.${X}"
				echo -e "${Y}${WARN}Copy & Paste this command into your PVE shell ${R}by your own risk!${X}"
				echo "-----------"
				echo -e "${C}${TAB}${START}qm set $VM_ID -$SATA_PORT /dev/disk/by-id/$SELECTED_DISK${X}"
				echo "-----------"
				sleep 3
			;;
        c) # Exit
            echo -e "${C}${OK}Exiting the script.${X}"
            echo ""
            exit 0
            ;;
        *) # False selection
            echo -e "${R}${WARN}Invalid input. Please choose 'a' | 'b' | 'c'.${X}"
            ;;
    esac
done
