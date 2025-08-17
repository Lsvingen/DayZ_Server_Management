#!/bin/bash
#############################################
### Initializing of Azure VM for hosting DayZ server
#############################################

# Get passed params
OPTIND=1         # Reset in case getopts has been used previously in the shell.
A=""
B=""
C=""
D=""
E=""
F=""
G=""
H=""

while getopts ":A:B:C:D:E:F:G:H:" opt; do
  case ${opt} in
    A ) SERVICE_USER=$OPTARG;;
    B ) ADMIN_USER=$OPTARG;;
    C ) ADMIN_STEAM_USER_IDS=$OPTARG;;
    D ) SERVER_MAP=$OPTARG;;
    E ) SERVER_EDITION=$OPTARG;;
    F ) SERVER_MODLIST=$OPTARG;;
    G ) SERVER_IP=$OPTARG;;
    H ) ADMIN_PASSWORD=$OPTARG;;
    \? ) echo "Usage: script [-A SERVICE_USER] [-B ADMIN_USER] [-C ADMIN__STEAM_USER_IDS] [-D SERVER_MAP] [-E SERVER_EDITION] [-F SERVER_MODLIST] [-G SERVER_IP] [-H ADMIN_PASSWORD]";;
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

STEAM_USERNAME=`az keyvault secret show --vault-name "priv-keyvault" --name "SteamUsername" --query value | tr -d '"'`
STEAM_PASSWORD=`az keyvault secret show --vault-name "priv-keyvault" --name "SteamPassword" --query value | tr -d '"'`

ADMIN_WEBHOOK_URL=`az keyvault secret show --vault-name "priv-keyvault" --name "DiscordAdminNotificationsWebhook" --query value | tr -d '"'`
SERVER_WEBHOOK_URL=`az keyvault secret show --vault-name "priv-keyvault" --name "DiscordServerNotificationsWebhook" --query value | tr -d '"'`

# Get the password to use for the Service Account running the server
DAYZ_SERVER_USER_PASSWORD=`az keyvault secret show --vault-name "priv-keyvault" --name "ServiceAccountPassword" --query value | tr -d '"'`
#dayz_server_user_password=`pwsh -command 'Connect-AzAccount -Identity | Out-Null; Get-AzKeyVaultSecret -VaultName "priv-keyvault" -Name "ServiceAccountPassword" -AsPlainText'`

# Get the password for the Admin account during provisioning, and add it to the keyvault for reference.
# If a secret with that name already exists, overwrite with the new value, if deleted recover and overwrite, if it does not exist we set to create it.
KEYVAULT_SECRETS=`az keyvault secret list --vault-name "priv-keyvault"`
KEYVAULT_DELETED_SECRETS=`az keyvault secret list-deleted --vault-name "priv-keyvault"`


if [[ $KEYVAULT_SECRETS = *AdminAccountPassword* ]]
then
	az keyvault secret set --vault-name "priv-keyvault" --name "AdminAccountPassword" --value "$ADMIN_PASSWORD"
elif [[ $KEYVAULT_DELETED_SECRETS = *AdminAccountPassword* ]]
then
	az keyvault secret recover --vault-name "priv-keyvault" --name "AdminAccountPassword"
	sleep 5
	az keyvault secret set --vault-name "priv-keyvault" --name "AdminAccountPassword" --value "$ADMIN_PASSWORD"
else
	az keyvault secret set --vault-name "priv-keyvault" --name "AdminAccountPassword" --value "$ADMIN_PASSWORD"
fi

#Create directories
sudo mkdir -m 777 /opt/dayz_server/
sudo mkdir -m 777 /opt/dayz_server/serverfiles/

#Download content
wget -O /opt/dayz_server/dayzserver.sh https://raw.githubusercontent.com/Lsvingen/DayZ_Server_Management/refs/heads/main/dayzserver.sh

#Create account for the server service account
sudo useradd -p $(openssl passwd -1 $DAYZ_SERVER_USER_PASSWORD) $SERVICE_USER -m -d /home/$SERVICE_USER

#Create group, the add members and permissions to the server dir
sudo groupadd dayz_server
sudo usermod -aG dayz_server $SERVICE_USER
sudo usermod -aG dayz_server $ADMIN_USER

sudo chgrp -R dayz_server /opt/dayz_server/
sudo chmod -R g+rwxs /opt/dayz_server/

#Server config
# Define the config file path
CONFIG_FILE="/opt/dayz_server/config.ini"

# Define Server folder location
SERVER_PATH="/opt/dayz_server/serverfiles"



# Variable substitutions/convertions from provisioning script parameters

# Set the branch to run
#stable=223350
#exp_branch=1042420
if [[ $SERVER_EDITION = "Stable" ]]
then
	BRANCH="223350"
elif [[ $SERVER_EDITION = "Experimental" ]]
then
	BRANCH="1042420"
fi

# Set the map to run, if an unexpected value is passed default to Chernarus
case "$SERVER_MAP" in
    "Chernarus") MISSION="dayzOffline.chernarusplus";;
    "Livonia") MISSION="dayzOffline.enoch";;
	  "Sakhal") MISSION="dayzOffline.sakhal";;
    *) MISSION="dayzOffline.chernarusplus";;
esac

# Define the mod list
MOD_LIST=""

# Replace delims in server mod list
SERVER_MODLIST="${SERVER_MODLIST//:/;}"

# Default content of the config.ini file
DEFAULT_CONFIG="
# DayZ SteamID
appid=\"$BRANCH\"
dayz_id=221100
#stable=223350
#exp_branch=1042420

# Game Port (Not Steam QueryPort. Add/Change that in your serverDZ.cfg file)
port=2301

# Server IP
server_IP=\"$SERVER_IP\"

# Server name
server_name="Flotedayrusen"

# Admin info
admin_list=\"$ADMIN__STEAM_USER_IDS\"
admin_password=\"$ADMIN_PASSWORD\"

# IMPORTANT PARAMETERS
steamloginuser=\"$STEAM_USERNAME\"
steamloginpassword=\"$STEAM_PASSWORD\"
config=serverDZ.cfg
BEpath=\"-BEpath=$SERVER_PATH/serverfiles/battleye/\"
profiles=\"-profiles=$SERVER_PATH/serverprofile/\"
# optional - just remove the # to enable
#logs=\"-dologs -adminlog -netlog\"

# Discord Notifications.
discord_webhook_url=\"$SERVER_WEBHOOK_URL\"
discord_webhook_admin_url=\"$ADMIN_WEBHOOK_URL\"

# Server map
mission=\"$MISSION\"

# DayZ Mods from Steam Workshop
# Edit the workshop.cfg and add one Mod Number per line.
# To enable mods, remove the # below and list the Mods like this: \"@mod1;@mod2;@spaces work\". Lowercase only.
#workshop=\"\"
# To enable serverside mods, remove the # below and list the Mods like this: \"@servermod1;@server mod2\". Lowercase only.
servermods=\"$SERVER_MODLIST\"

# modify carefully! server won't start if syntax is corrupt!
dayzparameter=\" -config=\${config} -port=\${port} -freezecheck \${BEpath} \${profiles} \${logs}\""

# Check if the config.ini file exists.
if [ ! -f "$CONFIG_FILE" ]; then
    printf "[ ${yellow}Warning${default} ] ${CONFIG_FILE} file not found.\n"
    echo -e "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    printf "[ ${green}Fixed${default} ] Default ${lightyellow}${CONFIG_FILE}${default} created.\n"
else
    printf "[ ${green}Success${default} ] Config file found. Reading values...\n"
    # Source the config file to load its variables
    source "$CONFIG_FILE"
    printf "[ ${green}Finished${default} ] Configuration file loaded.\n"
fi



# Install, configure and start server
#/bin/su -c "/opt/dayz_server/dayzserver.sh -i" - $SERVICE_USER #Install

#Replace mission details after install
#Change mapname
#grep -rl 'template="dayzOffline.chernarusplus"' $SERVER_PATH/serverfiles/serverDZ.cfg | xargs sed -i "s/template=\"dayzOffline.chernarusplus\"/template=\"$MISSION\"/g"

#Change hostname
#grep -rl '"EXAMPLE NAME"' $SERVER_PATH/serverfiles/serverDZ.cfg | xargs sed -i "s/\"EXAMPLE NAME\"/\"$server_name\"/g"

#Disable 3rd person
#grep -rl 'disable3rdPerson=0' $SERVER_PATH/serverfiles/serverDZ.cfg | xargs sed -i "s/"disable3rdPerson=0"/"disable3rdPerson=1"/g"

#/bin/su -c "/opt/dayz_server/dayzserver.sh -ws" - $SERVICE_USER #Configure mods
#/bin/su -c "/opt/dayz_server/dayzserver.sh -st" - $SERVICE_USER #Start