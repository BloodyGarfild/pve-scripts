#!/bin/bash
export LANG=en_US.UTF-8

# Import Misc
source <(curl -s https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/misc/colors.sh)
source <(curl -s https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/misc/emojis.sh)

# Clearing screen
clear

# Post message
echo ""
echo -e "${C}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++${X}"
echo -e "${C}++++++++++++++++++ vDSM-Arc-Installer +++++++++++++++++++${X}"
echo -e "${C}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++${X}"
echo ""

# Continue Script?
echo -e "${Y}vDSM-Arc default settings (can be changed after creation)${X}"
echo "-----"
echo -e "${Y}CPU: 2x | Mem: 4096MB | NIC: vmbr0 | Storage: selectable${X}"
echo -e "${R}vDSM-Arc will be mapped as SATA0 > Do not change this!${X}"
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

# Storage locations > support images
STORAGES=$(pvesm status -content images | awk 'NR>1 {print $1}')

# Check if storages exist
if [ -z "$STORAGES" ]; then
    echo -e "${R}${NOTOK}No storage locations found that support disk images.${X}"
    exit 1
fi

# Storage Options
echo -e "${G}${DISK}Please select target Storage for Arc install (SATA0):${X}"
select STORAGE in $STORAGES; do
    if [ -n "$STORAGE" ]; then
        echo -e "${G}You selected: $STORAGE${X}"
        break
    else
        echo -e "${R}Invalid selection. Please try again.${G}"
    fi
done

# Check for 'unzip' and 'wget' > install if not
for pkg in unzip wget; do
    if ! command -v "$pkg" &> /dev/null; then
        echo -e "${Y}'$pkg' is not installed. Installing...${X}"
        apt-get update && apt-get install -y "$pkg"
        if ! command -v "$pkg" &> /dev/null; then
            echo -e "${R}${NOTOK}Error: '$pkg' could not be installed. Exiting.${X}"
            exit 1
        fi
    fi
done

# Target directories
ISO_STORAGE_PATH="/var/lib/vz/template/iso"
DOWNLOAD_PATH="/var/lib/vz/template/tmp"

mkdir -p "$DOWNLOAD_PATH"

# Latest .img.zip from GitHub
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/AuxXxilium/arc/releases/latest | grep "browser_download_url" | grep ".img.zip" | cut -d '"' -f 4)
LATEST_FILENAME=$(basename "$LATEST_RELEASE_URL")

if [ -f "$DOWNLOAD_PATH/$LATEST_FILENAME" ]; then
    echo -e "${G}The latest file ($LATEST_FILENAME) is already present.${X}"
	echo -e "${G}Skipping download...${X}"
else
    echo -e "${G}Downloading the latest file ($LATEST_FILENAME)...${X}"
    wget -O "$DOWNLOAD_PATH/$LATEST_FILENAME" "$LATEST_RELEASE_URL"
fi

# Extract the file
echo -e "${Y}Extracting $LATEST_FILENAME...${X}"
unzip -o "$DOWNLOAD_PATH/$LATEST_FILENAME" -d "$ISO_STORAGE_PATH"

# Extract the version number from the filename
VERSION=$(echo "$LATEST_FILENAME" | grep -oP "\d+\.\d+\.\d+(-[a-zA-Z0-9]+)?")

# Rename arc.img to arc-[VERSION].img
if [ -f "$ISO_STORAGE_PATH/arc.img" ]; then
    NEW_IMG_FILE="$ISO_STORAGE_PATH/arc-${VERSION}.img"
    mv "$ISO_STORAGE_PATH/arc.img" "$NEW_IMG_FILE"
else
    echo -e "${R}Error: No extracted arc.img found!${X}"
    exit 1
fi

# VM-ID and configuration
VM_ID=$(pvesh get /cluster/nextid)
VM_NAME="vDSM.Arc"
STORAGE=$STORAGE
CORES=2
MEMORY=4096
Q35_VERSION="pc-q35-8.0"  

# Create the VM 
qm create "$VM_ID" --name "$VM_NAME" --memory "$MEMORY" --cores "$CORES" --net0 virtio,bridge=vmbr0 --machine "$Q35_VERSION"

# Set VirtIO-SCSI as the default controller
qm set "$VM_ID" --scsihw virtio-scsi-single

# Delete scsi0 if it exists
if qm config "$VM_ID" | grep -q "scsi0"; then
    qm set "$VM_ID" --delete scsi0
fi

# Import image
qm importdisk "$VM_ID" "$NEW_IMG_FILE" "$STORAGE"

# Check storage type
STORAGE_TYPE=$(pvesm status | awk -v s="$STORAGE" '$1 == s {print $2}')
echo -e "$STORAGE_TYPE"

# Disk format > block/file based
if [[ "$STORAGE_TYPE" == "dir" || "$STORAGE_TYPE" == "nfs" || "$STORAGE_TYPE" == "cifs" || "$STORAGE_TYPE" == "btrfs" ]]; then
    qm set "$VM_ID" --sata0 "$STORAGE:$VM_ID/vm-$VM_ID-disk-0.raw" # file-based 
else
	qm set "$VM_ID" --sata0 "$STORAGE:vm-${VM_ID}-disk-0" # block-based 
fi

# Enable QEMU Agent
qm set "$VM_ID" --agent enabled=1

# Set boot order to SATA0 only, disable all other devices
qm set "$VM_ID" --boot order=sata0
qm set "$VM_ID" --bootdisk sata0

# Disable all other boot devices
qm set "$VM_ID" --ide0 none
qm set "$VM_ID" --net0 virtio,bridge=vmbr0
qm set "$VM_ID" --cdrom none
qm set "$VM_ID" --delete ide0
qm set "$VM_ID" --delete ide2

clear

# Delete temp file?
echo ""
echo -e "${Y}${WARN} Do you want to delete the temp downloaded file ($LATEST_FILENAME) from $DOWNLOAD_PATH? (y/Y): ${X}"
read delete_answer
echo ""

if [[ "$delete_answer" =~ ^[Yy]$ ]]; then
    echo "Deleting the file..."
    rm -f "$DOWNLOAD_PATH/$LATEST_FILENAME"
    echo -e "${G}${OK}($LATEST_FILENAME) from '$DOWNLOAD_PATH' deleted.${X}"
else
    echo -e "${Y}${NOTOK}($LATEST_FILENAME) from '$DOWNLOAD_PATH' was not deleted.${X}"
fi

# Success message
echo "------"
echo -e "${G}${OK} VM $VM_NAME (ID: $VM_ID) has been successfully created!${X}"
echo -e "${G}${OK} SATA0: Imported image (${NEW_IMG_FILE})${X}"
echo "------"

# Choose the Hard Disk 
while true; do
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
