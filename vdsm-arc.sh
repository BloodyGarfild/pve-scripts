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
echo -e "${C}+++++++++++++++++ vDSM-Arc-Installer ++++++++++++++++++${X}"
echo -e "${C}+++++++++++++++++++++++++++++++++++++++++++++++++++++++${X}"
echo""

# Ask for continue script
echo -e "${Y}vDSM-Arc default settings (can changed after creation)${X}"
echo "-----"
echo -e "${Y}CPU: 2 Cores | Mem: 4096MB | NIC: vmbr0 | Storage: local-lvm${X}"
echo -e "${R}vDSM-Arc will be mapped as SATA0 > Do not change this!${X}"
echo "-----"
echo ""
echo -e "${Y}${INFO}Run script now? (y/N)${X}"
read run_script
echo ""

if [[ "$run_script" =~ ^[Yy]$ ]]; then
		echo -e "${G}${OK}Running...${X}"
    else
		echo -e "${R}${NOTOK}Stopping...${X}"
		exit 1
fi


# Check if 'unzip' and 'wget' are installed
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

# Retrieve the latest .img.zip from GitHub
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/AuxXxilium/arc/releases/latest | grep "browser_download_url" | grep ".img.zip" | cut -d '"' -f 4)
LATEST_FILENAME=$(basename "$LATEST_RELEASE_URL")

if [ -f "$DOWNLOAD_PATH/$LATEST_FILENAME" ]; then
    echo -e "${G}The latest file ($LATEST_FILENAME) is already present. Skipping download.${X}"
else
    echo -e "${G}Downloading the latest file ($LATEST_FILENAME)...${X}"
    wget -O "$DOWNLOAD_PATH/$LATEST_FILENAME" "$LATEST_RELEASE_URL"
fi

# Extract the file
echo -e "${Y}Extracting $LATEST_FILENAME...${X}"
unzip -o "$DOWNLOAD_PATH/$LATEST_FILENAME" -d "$ISO_STORAGE_PATH"

# Extract the version number from the filename
VERSION=$(echo "$LATEST_FILENAME" | grep -oP "\d+\.\d+\.\d+(-[a-zA-Z0-9]+)?")

# Rename the extracted arc.img to arc-[VERSION].img
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
STORAGE="local-lvm"
CORES=2
MEMORY=4096

# Retrieve Proxmox version to set the correct q35 version
Q35_VERSION="pc-q35-8.0"  # Change as needed for the correct Proxmox version!

# Create the VM with q35 as the machine type
qm create "$VM_ID" --name "$VM_NAME" --memory "$MEMORY" --cores "$CORES" --net0 virtio,bridge=vmbr0 --machine "$Q35_VERSION"

# Set VirtIO-SCSI as the default controller
qm set "$VM_ID" --scsihw virtio-scsi-single

# Delete scsi0 if it exists
if qm config "$VM_ID" | grep -q "scsi0"; then
    qm set "$VM_ID" --delete scsi0
fi

# Import the renamed image without --format qcow2 (will default to raw!)
qm importdisk "$VM_ID" "$NEW_IMG_FILE" "$STORAGE"

# Set the imported image as SATA0
qm set "$VM_ID" --sata0 "$STORAGE:vm-${VM_ID}-disk-0"

# Enable QEMU Agent
qm set "$VM_ID" --agent enabled=1

# Set boot order to SATA0 only, disable all other devices
qm set "$VM_ID" --boot order=sata0
qm set "$VM_ID" --bootdisk sata0

# Disable all other boot devices
qm set "$VM_ID" --ide0 none
qm set "$VM_ID" --net0 virtio,bridge=vmbr0
qm set "$VM_ID" --cdrom none

clear

# Ask if the temporary file should be deleted
echo -e "${Y}${WARN} Do you want to delete the downloaded file ($LATEST_FILENAME) from $DOWNLOAD_PATH? (y/N): ${X}"
read delete_answer
echo ""

if [[ "$delete_answer" =~ ^[Yy]$ ]]; then
    echo "Deleting the file..."
    rm -f "$DOWNLOAD_PATH/$LATEST_FILENAME"
    echo -e "${G}${OK}($LATEST_FILENAME) from '$DOWNLOAD_PATH' deleted.${X}"
else
    echo -e "${Y}${NOTOK}($LATEST_FILENAME) from '$DOWNLOAD_PATH' was not deleted.${X}"
fi

# Success
echo "-----"
echo -e "${G}${OK} VM $VM_NAME (ID: $VM_ID) has been successfully created!${X}"
echo -e "${G}${OK} SATA0: Imported image (${NEW_IMG_FILE})${X}"
echo "-----"

# Choose the Hard Disk 
while true; do
echo ""
echo -e "${Y}${DISK}Choose your option:${X}"
echo -e "${C}a) Virtual Hard Disk${X}"
echo -e "${C}b) Physical Hard Disk${X}"
echo -e "${R}c) Exit${X}"
read -n 1 option

	case "$option" in
		a)
			echo -e "${C}Virtual Hard Disk${X}"
			echo ""
			echo -e "${Y}${INFO}PVE > $VM_ID > Hardware > Add > Hard Disk (SATA1, SATA2,..)${X}"
			;;
		b)
			echo -e "${C}Physical Hard Disk${X}"
			ls -l /dev/disk/by-id
			echo ""
			echo -e "${C}Search for the disk you want to use...${X}"
			echo -e "${C}Edit the following line and run in PVE shell:${X}"
			echo -e "${Y}${INFO} qm set $VM_ID -sata1 /dev/disk/by-id/ata-Samsung_SSD_870_QVO_8TB_XXSERIALNRXXX${X}"
			;;
		c)
			echo -e "${C}${OK}Exiting the script.${X}"
			exit 0
			;;
		*)
			echo -e "${R}${WARN}Invalid input. Please choose 'a' | 'b' | 'c'.${X}"
			;;
	esac
done
