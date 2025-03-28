# pve-scripts 

**Just copy & paste into your PVE shell 😎**

## 📟 **vdsm-arc.sh** 

An automated install script for **vDSM Arc Loader** from [AuxXxilium](https://github.com/AuxXxilium) on your PVE host.

- **Default settings**:  
  - **CPU**: 2 Cores  
  - **RAM**: 4096MB  
  - **NIC**: vmbr0  
  - **Storage**: Selectable
- **Supported filesystem types**:  
  `dir`, `btrfs`, `nfs`, `cifs`, `lvm`, `lvmthin`, `zfs`, `zfspool`   
  
```shell
bash -c "$(wget -qLO - https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/vdsm-arc.sh)"
```

---

## 📟 vm-disk-update.sh

Add more virtual or physical disks to an existing VM on your PVE host   

- **Supported filesystem types**:  
  `dir`, `btrfs`, `nfs`, `cifs`, `lvm`, `lvmthin`, `zfs`, `zfspool`   
  
```shell
bash -c "$(wget -qLO - https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/vm-disk-update.sh)"
```

---

## 📟 laptop-hibernation.sh

This script disable any hibernation mode to run Proxmox VE on a laptop   
  
```shell
bash -c "$(wget -qLO - https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/laptop-hibernation.sh)"
```
