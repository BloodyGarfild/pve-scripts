## pve-scripts
Just copy & paste into your PVE shell 😎


## vdsm-arc.sh
> Full automated Install script for vDSM Arc Loader from [AuxXxilium](https://github.com/AuxXxilium) on your PVE host  
> _Default VM: 2x CPU | 4096M RAM | Storage: selectable_  
> _Supported filesystem types:_ dir, btrfs, nfs, cifs, lvm, lvmthin, zfs, zfspool
```shell
bash -c "$(wget -qLO - https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/vdsm-arc.sh)"
```



## vm-disk-update.sh
> Add more virtual disks or physical disks to an existing VM on your PVE host   
> _Supported filesystem types:_ dir, btrfs, nfs, cifs, lvm, lvmthin, zfs, zfspool  
```shell
bash -c "$(wget -qLO - https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/vm-disk-update.sh)"
```



## laptop-hibernation.sh
> This script disable any hibernation mode to run Proxmox on a laptop  
```shell
bash -c "$(wget -qLO - https://raw.githubusercontent.com/And-rix/pve-scripts/refs/heads/main/laptop-hibernation.sh)"
```
