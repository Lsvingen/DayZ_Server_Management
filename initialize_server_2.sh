#!/bin/bash
#############################################
### Initializing of Azure VM for hosting DayZ server
#############################################

# Get passed params
OPTIND=1         # Reset in case getopts has been used previously in the shell.
a=""
b=""
c=""
d=""
e=""
f=""

while getopts ":a:b:c:d:e:f:" opt; do
  case ${opt} in
    a ) SERVICE_USER=$OPTARG;;
    b ) ADMIN_USER=$OPTARG;;
    c ) ADMIN__STEAM_USER_IDS=$OPTARG;;
    d ) SERVER_MAP=$OPTARG;;
    e ) SERVER_EDITION=$OPTARG;;
    f ) SERVER_MODLIST=$OPTARG;;
    \? ) echo "Usage: script [-a SERVICE_USER] [-b ADMIN_USER] [-c ADMIN__STEAM_USER_IDS] [-d SERVER_MAP] [-e SERVER_EDITION] [-f SERVER_MODLIST]";;
  esac
done


# Enable SSH, restrictions for management are done via NSG from the Terraform deployment
# Install dependencies
sudo apt install openssh-server -y
sudo apt install lib32gcc-s1 -y
#snap install powershell --classic

# Install Powershell modules required for access to keyvault
#TrustPSRepo=`pwsh -command 'Set-PSRepository -Name PSGallery -InstallationPolicy Trusted'
#InstallModule=`pwsh -command 'install-module Az -Confirm:$false -Force'`
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Get Steam Account login details from Azure Key Vault using Managed Identity for use with steamcmd
#SteamUsername=`pwsh -command 'Connect-AzAccount -Identity | Out-Null; Get-AzKeyVaultSecret -VaultName "priv-keyvault" -Name "SteamUsername" -AsPlainText'`
#SteamPassword=`pwsh -command 'Connect-AzAccount -Identity | Out-Null; Get-AzKeyVaultSecret -VaultName "priv-keyvault" -Name "SteamPassword" -AsPlainText'`

az login --identity

SteamUsername=`az keyvault secret show --vault-name "priv-keyvault" --name "SteamUsername" --query value | tr -d '"'`
SteamPassword=`az keyvault secret show --vault-name "priv-keyvault" --name "SteamPassword" --query value | tr -d '"'`

# Get password to use for Service Account running the server
dayz_server_user_password=`az keyvault secret show --vault-name "priv-keyvault" --name "ServiceAccountPassword" --query value | tr -d '"'`
#dayz_server_user_password=`pwsh -command 'Connect-AzAccount -Identity | Out-Null; Get-AzKeyVaultSecret -VaultName "priv-keyvault" -Name "ServiceAccountPassword" -AsPlainText'`

#Create directories
sudo mkdir -m 777 /opt/dayz_server/
sudo mkdir -m 777 /opt/dayz_server/serverfiles/

#Create group, the add members and permissions to the server dir
sudo groupadd dayz_server
sudo usermod -aG dayz_server $SERVICE_USER
sudo usermod -aG dayz_server $ADMIN_USER

sudo chgrp -R dayz_server /opt/dayz_server/
sudo chmod -R g+rwX /opt/dayz_server/

#Create account for the server service account
sudo useradd -p $(openssl passwd -1 ${dayz_server_user_password}) $SERVICE_USER -m -d /home/$SERVICE_USER

#Download content
wget -O /opt/dayz_server/dayzserver.sh https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/dayzserver.sh

# Run script in different context from root
/bin/su -c "/opt/dayz_server/dayzserver.sh -u ${SteamUsername} -p ${SteamPassword}" - dayz_server_user