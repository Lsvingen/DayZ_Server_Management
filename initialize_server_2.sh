#!/bin/bash
#############################################
### Initializing of Azure VM for hosting DayZ server
#############################################

#Enable SSH, restrictions for management are done via NSG from the Terraform deployment
sudo apt install openssh-server -y
sudo apt install lib32gcc-s1 -y

#Download and execute DayZ server management script
#wget -qO - https://github.com/Lsvingen/DayZ_Server_Management/blob/main/dayzserver.sh | bash -s param1 param2 ...

mkdir -m 777 /opt/dayz_server/

wget -O /opt/dayz_server/dayzserver.sh https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/dayzserver.sh
wget -O /opt/dayz_server/config.ini https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/config.ini
chmod +x /opt/dayz_server/dayzserver.sh

# Create account to use
# Will fix this later
sudo useradd -p $(openssl passwd -1 PelicanParty/874) dayz_server_user
/bin/su -c "/opt/dayz_server/dayzserver.sh" - dayz_server_user