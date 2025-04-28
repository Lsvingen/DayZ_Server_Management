#!/bin/bash
#############################################
### Initializing of Azure VM for hosting DayZ server
#############################################

#Enable SSH, restrictions for management are done via NSG from the Terraform deployment
sudo apt install openssh-server

#Download and execute DayZ server management script
#wget -qO - https://github.com/Lsvingen/DayZ_Server_Management/blob/main/dayzserver.sh | bash -s param1 param2 ...

mkdir -m 777 /opt/dayz_server/

wget -O - https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/dayzserver.sh --output-file=/opt/dayz_server/dayzserver.sh
chmod +x /opt/dayz_server/dayzserver.sh
bash /opt/dayz_server/dayzserver.sh
