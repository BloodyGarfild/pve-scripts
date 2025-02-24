#!/bin/bash
export LANG=en_US.UTF-8

TEST123="

# Continue Script?
echo -e "${Y}vDSM-Arc default settings (can changed after creation)${X}"
echo "-----"
echo -e "${Y}CPU: 2x | Mem: 4096MB | NIC: vmbr0 | Storage: selectable${X}"
echo -e "${R}vDSM-Arc will be mapped as SATA0 > Do not change this!${X}"
echo "-----"
echo ""
echo -e "${Y}${INFO}Run script now? (y/N)${X}"
read run_script
echo ""

"
