#!/bin/bash
#############################################
### Initializing of Azure VM for hosting DayZ server
#############################################

#Enable SSH, restrictions for management are done via NSG from the Terraform deployment
sudo apt install openssh-server

#Download and execute DayZ server management script
#wget -qO - https://github.com/Lsvingen/DayZ_Server_Management/blob/main/dayzserver.sh | bash -s param1 param2 ...

wget -O - https://github.com/Lsvingen/DayZ_Server_Management/blob/main/dayzserver.sh
chmod +x ./dayzserver.sh
bash ./dayzserver.sh
