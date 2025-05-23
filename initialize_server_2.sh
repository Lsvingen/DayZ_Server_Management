#!/bin/bash
#############################################
### Initializing of Azure VM for hosting DayZ server
#############################################

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

sudo mkdir -m 777 /opt/dayz_server/
sudo mkdir -m 777 /opt/dayz_server/serverfiles/

wget -O /opt/dayz_server/dayzserver.sh https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/dayzserver.sh
sudo chmod +x /opt/dayz_server/dayzserver.sh

# Create account to use, add permisions on folder an kick off script
# Will fix this later
sudo useradd -p $(openssl passwd -1 ${dayz_server_user_password}) dayz_server_user -m -d /home/dayz_server_user
sudo chown -R dayz_server_user /opt/dayz_server/

# Run script in different context from root
/bin/su -c "/opt/dayz_server/dayzserver.sh -u ${SteamUsername} -p ${SteamPassword}" - dayz_server_user