#!/bin/bash
#############################################
### Initializing of Azure VM for hosting DayZ server
#############################################

# Enable SSH, restrictions for management are done via NSG from the Terraform deployment
# Install dependencies
sudo apt install openssh-server -y
sudo apt install lib32gcc-s1 -y
snap install powershell --classic

# Install Powershell modules required for access to keyvault
powershell -command 'install-module Az -Confirm:$false | Out-Null'

# Get Steam Account login details from Azure Key Vault using Managed Identity for use with steamcmd
SteamUsername=`powershell -command 'Connect-AzAccount -Identity | Out-Null; Get-AzKeyVaultSecret -VaultName "priv-keyvault" -Name "SteamUsername" -AsPlainText'`
SteamPassword=`powershell -command 'Connect-AzAccount -Identity | Out-Null; Get-AzKeyVaultSecret -VaultName "priv-keyvault" -Name "SteamPassword" -AsPlainText'`

# Get password to use for Service Account running the server
dayz_server_user_password=`powershell -command 'Connect-AzAccount -Identity | Out-Null; Get-AzKeyVaultSecret -VaultName "priv-keyvault" -Name "ServiceAccountPassword" -AsPlainText'`

mkdir -m 777 /opt/dayz_server/
mkdir -m 777 /opt/dayz_server/serverfiles/

wget -O /opt/dayz_server/dayzserver.sh https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/dayzserver.sh
wget -O /opt/dayz_server/config.ini https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/config.ini
chmod +x /opt/dayz_server/dayzserver.sh

# Create account to use, add permisions on folder an kick off script
# Will fix this later
sudo useradd -p $(openssl passwd -1 ${dayz_server_user_password}) dayz_server_user
sudo chown -R dayz_server_user /opt/dayz_server/serverfiles/

# Run script in different context from root
/bin/su -c "/opt/dayz_server/dayzserver.sh -u ${SteamUsername} -p ${SteamPassword}" - dayz_server_user