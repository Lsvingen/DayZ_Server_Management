#!/bin/bash
#############################################
### DayZ Standalone Linux Server script
### Original script by thelastnoc
### Modified by haywardgg
#############################################

OPTIND=1         # Reset in case getopts has been used previously in the shell.
A=""
B=""
C=""
D=""
E=""
F=""
G=""
H=""
I=""

while getopts ":A:B:C:D:E:F:G:H:I:" opt; do
  case ${opt} in
    A ) STEAM_USERNAME=$OPTARG;;
    B ) STEAM_PASSWORD=$OPTARG;;
	C ) ADMIN__STEAM_USER_IDS=$OPTARG;;
    D ) SERVER_MAP=$OPTARG;;
    E ) SERVER_EDITION=$OPTARG;;
    F ) SERVER_MODLIST=$OPTARG;;
    G ) SERVER_IP=$OPTARG;;
    H ) ADMIN_DISCORD_WEBHOOK=$OPTARG;;
    I ) SERVER_DISCORD_WEBHOOK=$OPTARG;;
    \? ) echo "Usage: script [-A STEAM_USERNAME] [-B STEAM_PASSWORD] [-C ADMIN__STEAM_USER_IDS] [-D SERVER_MAP] [-E SERVER_EDITION] [-F SERVER_MODLIST] [-G SERVER_IP] [-H ADMIN_DISCORD_WEBHOOK] [-I SERVER_DISCORD_WEBHOOK]";;
  esac
done

### NO NEED TO EDIT ANYTHING IN THIS FILE ###
### Changes should be made in config.ini ###

if [ "${ansi}" != "off" ]; then
        # echo colors
        default="\e[0m"
        red="\e[31m"
        green="\e[32m"
        yellow="\e[33m"
        lightyellow="\e[93m"
        blue="\e[34m"
        lightblue="\e[94m"
        magenta="\e[35m"
        cyan="\e[36m"
        # carriage return & erase to end of line
        creeol="\r\033[K"
fi

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

# Set VPPAdminTool permissions
ADMINLIST_DELIM=":"
ADMINLIST_OUTPUTFILE="/profiles/VPPAdminTools/Permissions/SuperAdmins/SuperAdmins.txt"
ADMINLIST_PASSWORDFILE="/profiles/VPPAdminTools/Permissions/Credentials.txt"

# Save original IFS
OIFS=$IFS
# Set IFS to the delimiter
IFS=$ADMINLIST_DELIM

# Split the string and loop through parts
#for part in $ADMIN__STEAM_USER_IDS; do
#    echo "$part" >> "$ADMINLIST_OUTPUTFILE"
#done

# Restore IFS
IFS=$OIFS


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

# IMPORTANT PARAMETERS
steamloginuser=\"$STEAM_USERNAME\"
steamloginpassword=\"$STEAM_PASSWORD\"
config=serverDZ.cfg
BEpath=\"-BEpath=$SERVER_PATH/serverfiles/battleye/\"
profiles=\"-profiles=$SERVER_PATH/serverprofile/\"
# optional - just remove the # to enable
#logs=\"-dologs -adminlog -netlog\"

# Discord Notifications.
discord_webhook_url=\"$SERVER_DISCORD_WEBHOOK\"
discord_webhook_admin_url=\"$ADMIN_DISCORD_WEBHOOK\"

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

fn_send_admin_login_notification(){
	# Send Discord Admin login notification if URL is set
	if [ -n "$discord_webhook_admin_url" ]; then
		curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"Attempting steamcmd login for account "${steamloginuser}", please check Steam Guard.\"}" "$discord_webhook_admin_url"
	else
		echo "Discord webhook URL is not set. Skipping notification for login"
	fi
}

fn_get_serverlist_DZSAL(){
	#pwsh -command "(Invoke-RestMethod -Method Get -Uri 'dayzsalauncher.com/api/v2/launcher/servers/dayz').result.endpoint.ip -contains '108.143.148.177'"
	serverListRequest=`curl -H "Content-Type: application/json" -X GET "https://dayzsalauncher.com/api/v2/launcher/servers/dayz"`
}

fn_add_server_DZSAL(){
	# Send API call to add server to DZSAL if it is provided
	if [ -n "$SERVER_IP" ]; then
		curl -H "Content-Type: application/json" -X GET "https://dayzsalauncher.com/api/v1/query/$SERVER_IP:27016"
	else
		echo ""
	fi
}

fn_checkroot_dayz(){
	if [ "$(whoami)" == "root" ]; then
	  printf "[ ${red}FAIL${default} ] ${yellow}Do NOT run this script as root!\n"
	  printf "\tSwitch to the dayz user!${default}\n"
	  exit 1
	fi
}

check_dependencies(){
	    missing_tools=()
	    tools=("tmux" "curl" "jq" "wget")
	    libraries=("lib32gcc-s1")
	
	    # Check executables
	    for tool in "${tools[@]}"; do
	        if ! command -v "$tool" &>/dev/null; then
	            missing_tools+=("$tool")
	        fi
	    done
	
	    # Check libraries
	    for lib in "${libraries[@]}"; do
	        if ! dpkg -l | grep -q "$lib"; then
	            missing_tools+=("$lib")
	        fi
	    done
	
	    if [ "${#missing_tools[@]}" -ne 0 ]; then
	        echo -e "[ ${red}ERROR${default} ] The following dependencie(s) are missing and must be installed:"
	        for tool in "${missing_tools[@]}"; do
	            echo "  - $tool"
	        done
	        echo -e "[ ${yellow}INFO${default} ] Install these dependencie(s) using your package manager. For example:"
	        echo "      sudo apt install ${missing_tools[*]}   # For Debian/Ubuntu"
	        echo "      sudo yum install ${missing_tools[*]}   # For CentOS/RHEL"
	        echo "      sudo dnf install ${missing_tools[*]}   # For Fedora"
	        echo "      sudo pacman -S ${missing_tools[*]}     # For Arch"
	        exit 1
	    else
	        echo -e "[ ${green}OK${default} ] All required tools are installed."
	    fi
}


fn_checkscreen(){
	if [ -n "${STY}" ]; then
		printf "[ ${red}FAIL${default} ] The Script creates a tmux session when starting the server.\n"
		printf "\tIt is not possible to run a tmux session inside screen session\n"
		exit 1
	fi
}

fn_status_dayz(){
	dayzstatus=$(tmux list-sessions -F $(whoami)-tmux 2> /dev/null | grep -Ecx $(whoami)-tmux)
}

fn_clear_logs(){
	# Delete *.RPT, *.log, and *.mdmp files from the profiles directory
	profiles_dir="${SERVER_PATH}/serverprofile" # Update this path if necessary
	if [ -d "${profiles_dir}" ]; then
		find "${profiles_dir}" -type f \( -name "*.RPT" -o -name "*.log" -o -name "*.mdmp" \) -delete
		printf "[ ${green}DayZ${default} ] Cleared old .RPT, .log, and .mdmp files from profiles directory.\n"
	fi
}


fn_start_dayz(){
	fn_status_dayz
	if [ "${dayzstatus}" == "1" ]; then
		printf "[ ${yellow}DayZ${default} ] Server already running.\n"
		exit 1
	else
                fn_backup_dayz
                fn_update_dayz
                fn_workshop_mods
		fn_clear_logs
		printf "[ ${green}DayZ${default} ] Starting server...\n"
		sleep 0.5
		sleep 0.5
		cd ${SERVER_PATH}/serverfiles
		tmux new-session -d -x 23 -y 80 -s $(whoami)-tmux ./DayZServer $dayzparameter -mod="$workshop" -servermod="$servermods"
		sleep 1
		cd ${HOME}
		date > ${SERVER_PATH}/.dayzlockfile
	fi
}

fn_stop_dayz(){
	fn_status_dayz
	if [ "${dayzstatus}" == "1" ]; then
		printf "[ ${magenta}...${default} ] Stopping Server graceful."
		# waits up to 90 seconds giving the server time to shutdown gracefuly
		for seconds in {1..90}; do
			fn_status_dayz
			if [ "${dayzstatus}" == "0" ]; then
				printf "\r[ ${green}OK${default} ] Stopping Server graceful.\n"
				rm -f ${SERVER_PATH}/.dayzlockfile
				break
			fi
			printf "\r[ ${magenta}...${default} ] Stopping Server graceful: ${seconds} seconds"
			tmux send-keys C-c -t $(whoami)-tmux > /dev/null 2>&1
			sleep 1
		done
		fn_status_dayz
		if [ "${dayzstatus}" != "0" ]; then
			printf "\n[ ${red}FAIL${default} ] Stopping Server graceful failed. Stop Signal.\n"
			sleep 2
			rm -f ${SERVER_PATH}/.dayzlockfile
			tmux kill-session -t $(whoami)-tmux
			#killall -u $(whoami)
		fi
	else
		printf "[ ${yellow}DayZ${default} ] Server not running.\n"
	fi
}

fn_restart_dayz(){
	fn_stop_dayz
	sleep 1
	fn_start_dayz
}

fn_monitor_dayz(){
	if [ ! -f ".dayzlockupdate" ]; then
		fn_status_dayz
		if [ "${dayzstatus}" == "0" ] && [ -f "${SERVER_PATH}/.dayzlockfile" ]; then
			fn_restart_dayz
		elif [ "${dayzstatus}" != "0" ] && [ -f "${SERVER_PATH}/.dayzlockfile" ]; then
			printf "[ ${lightblue}INFO${default} ] Server should be online!\n"
		else
			printf "[ ${yellow}INFO${default} ] Don't use monitor to start the server. Use the start command.\n"
		fi
	else
		printf "[ ${yellow}INFO${default} ] Serverfiles being updated\n."
	fi
}

fn_console_dayz(){
	printf "[${yellow} Warning ${default}] Press \"CTRL+b\" then \"d\" to exit console.\n    Do NOT press CTRL+c to exit.\n\n"
	sleep 0.1
	while true; do
                read -e -i "Y" -p "Continue? [Y/n] " -r answer
                case "${answer}" in
                        [Yy]|[Yy][Ee][Ss]) tmux a -t $(whoami)-tmux
                                           return 0;;
                        [Nn]|[Nn][Oo]) return 1 ;;
                *) echo "Please answer yes or no." ;;
                esac
        done
}


fn_install_dayz(){
	if [ ! -f "${SERVER_PATH}/steamcmd/steamcmd.sh" ]; then
		mkdir ${SERVER_PATH}/steamcmd &> /dev/null
		curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxf - -C "${SERVER_PATH}/steamcmd/"
		printf "[ ${yellow}STEAM${default} ] Steamcmd installed\n"
	else
		printf "[ ${lightblue}STEAM${default} ] Steamcmd already installed\n"
	fi
	if [ ! -f "${SERVER_PATH}/serverfiles/DayZServer" ]; then
		mkdir ${SERVER_PATH}/serverfiles &> /dev/null
		mkdir ${SERVER_PATH}/serverprofile &> /dev/null
		printf "[ ${yellow}DayZ${default} ] Downloading DayZ Server-Files!\n"
		fn_runvalidate_dayz
	else
		printf "[ ${lightblue}DayZ${default} ] The Server is already installed.\n"
		fn_opt_usage
	fi
}

fn_runupdate_dayz(){
	fn_send_admin_login_notification
	${SERVER_PATH}/steamcmd/steamcmd.sh +force_install_dir ${SERVER_PATH}/serverfiles +login "${steamloginuser}" "${steamloginpassword}"  +app_update "${appid}" +quit
}

fn_update_dayz(){
	fn_send_admin_login_notification
	appmanifestfile=${SERVER_PATH}/serverfiles/steamapps/appmanifest_"${appid}".acf
	printf "[ ... ] Checking for update: SteamCMD"
	# gets currentbuild
	currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d \  -f3)
	# Removes appinfo.vdf as a fix for not always getting up to date version info from SteamCMD
	if [ -f "${SERVER_PATH}/Steam/appcache/appinfo.vdf" ]; then
		rm -f "${SERVER_PATH}/Steam/appcache/appinfo.vdf"
		sleep 1
	fi
	# check for new build
	fn_send_admin_login_notification
	availablebuild=$(${SERVER_PATH}/steamcmd/steamcmd.sh +login "${steamloginuser}" "${steamloginpassword}" +app_info_update 1 +app_info_print "${appid}" +app_info_print "${appid}" +quit | sed -n '/branch/,$p' | grep -m 1 buildid | tr -cd '[:digit:]')
	if [ -z "${availablebuild}" ]; then
		printf "\r[ ${red}FAIL${default} ] Checking for update: SteamCMD\n"
		sleep 0.5
		printf "\r[ ${red}FAIL${default} ] Checking for update: SteamCMD: Not returning version info\n"
		exit
	else
		printf "\r[ ${green}OK${default} ] Checking for update: SteamCMD"
		sleep 0.5
	fi
	# compare builds
	if [ "${currentbuild}" != "${availablebuild}" ]; then
		printf "\r[ ${green}OK${default} ] Checking for update: SteamCMD: Update available\n"
		printf "Update available:\n"
		sleep 0.5
		printf "\tCurrent build: ${red}${currentbuild}${default}\n"
		printf "\tAvailable build: ${green}${availablebuild}${default}\n"
		printf "\thttps://steamdb.info/app/${appid}/\n"
		sleep 0.5
		date > ${SERVER_PATH}/.dayzlockupdate
		printf "\nApplying update"
		for seconds in {1..3}; do
			printf "."
			sleep 1
		done
		printf "\n"
		# run update
		fn_status_dayz
		if [ "${dayzstatus}" == "0" ]; then
			fn_runupdate_dayz
			fn_workshop_mods
			rm -f ${SERVER_PATH}/.dayzlockupdate
		else
			fn_stop_dayz
			fn_runupdate_dayz
			fn_workshop_mods
			fn_start_dayz
			rm -f ${SERVER_PATH}/.dayzlockupdate
		fi
	else
		printf "\r[ ${green}OK${default} ] Checking for update: SteamCMD: No update available\n"
		printf "\nNo update available:\n"
		printf "\tCurrent version: ${green}${currentbuild}${default}\n"
		printf "\tAvailable version: ${green}${availablebuild}${default}\n"
		printf "\thttps://steamdb.info/app/${appid}/\n\n"
	fi
}

fn_runvalidate_dayz(){
	fn_send_admin_login_notification
	${SERVER_PATH}/steamcmd/steamcmd.sh +force_install_dir ${SERVER_PATH}/serverfiles +login "${steamloginuser}" "${steamloginpassword}" +app_update "${appid}" validate +quit
}

fn_validate_dayz(){
	if [ "${dayzstatus}" == "0" ]; then
		fn_runvalidate_dayz
	else
		date > ${SERVER_PATH}/.dayzlockupdate
		fn_stop_dayz
		fn_runvalidate_dayz
		fn_workshop_mods
		rm -f ${SERVER_PATH}/.dayzlockupdate
		fn_start_dayz
	fi
}

fn_workshop_mods(){
    declare -a workshopID
    workshopfolder="${SERVER_PATH}/serverfiles/steamapps/workshop/content/221100"
    workshoplist=""
    timestamp_file="${SERVER_PATH}/mod_timestamps.json"
    workshop_cfg="${SERVER_PATH}/workshop.cfg"
    
    # If .workshop.cfg doesn't exist, create it.
    if [ ! -f "$workshop_cfg" ]; then
        touch $workshop_cfg
	chmod 600 ${SERVER_PATH}/workshop.cfg
    fi

    # Read the updated workshop.cfg into workshopID array
    mapfile -t workshopID < "$workshop_cfg"

    # Initialize timestamp file if it doesn't exist
    if [ ! -f "$timestamp_file" ]; then
        echo "{}" > "$timestamp_file"
        echo "Timestamp file '$timestamp_file' created."
    fi

    # Gather mods for download
    for i in "${workshopID[@]}"; do
        mod_id=$(echo "$i" | awk '{print $1}')
        if [[ "$mod_id" =~ ^[0-9]+$ ]]; then
            workshoplist+=" +workshop_download_item "${dayz_id}" "$mod_id""
        fi
    done

    # Download mods
	fn_send_admin_login_notification
    ${SERVER_PATH}/steamcmd/steamcmd.sh +force_install_dir ${SERVER_PATH}/serverfiles +login "${steamloginuser}" "${steamloginpassword}" ${workshoplist} +quit

    # Link mods and check for updates
    for i in "${workshopID[@]}"; do
        mod_id=$(echo "$i" | awk '{print $1}')
        mod_name=$(echo "$i" | cut -d' ' -f2-)

        if [[ "$mod_id" =~ ^[0-9]+$ ]] && [ -d "${workshopfolder}/$mod_id" ]; then
            mod_meta_file="${workshopfolder}/$mod_id/meta.cpp"
            
            # Ensure mod_name is accurate
            if [ -f "$mod_meta_file" ]; then
                actual_mod_name=$(cut -d '"' -f 2 <<< $(grep name "$mod_meta_file"))
                mod_name=${actual_mod_name:-$mod_name}
            fi

            # Convert modname to lowercase
            mod_name=$(echo "${mod_name}" | tr '[:upper:]' '[:lower:]')

            # Rename main mod folder to lowercase if necessary
            if [ ! -d "${SERVER_PATH}/serverfiles/@${mod_name}" ]; then
                mv "${SERVER_PATH}/serverfiles/@$(basename "${workshopfolder}/$mod_id")" "${SERVER_PATH}/serverfiles/@${mod_name}" 2>/dev/null
            fi

            # Create a symlink if it doesn't already exist
            if [ ! -d "${SERVER_PATH}/serverfiles/@${mod_name}" ]; then
                ln -s ${workshopfolder}/$mod_id "${SERVER_PATH}/serverfiles/@${mod_name}" &> /dev/null
            fi

            # Check if mod has been updated
            mod_last_modified=$(date -r "$mod_meta_file" +%s 2>/dev/null || echo 0)
            prev_timestamp=$(jq -r --arg mod "$mod_id" '.[$mod] // 0' "$timestamp_file")

            if [ "$mod_last_modified" -gt "$prev_timestamp" ]; then
                # Send Discord notification if URL is set
                if [ -n "$discord_webhook_url" ]; then
                    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"The mod '$mod_name' (ID: $mod_id) has been updated.\"}" "$discord_webhook_url"
                else
                    echo "Discord webhook URL is not set. Skipping notification for mod '$mod_name'."
                fi
                
                # Update timestamp file
                jq --arg mod "$mod_id" --argjson time "$mod_last_modified" '.[$mod] = $time' "$timestamp_file" > "${timestamp_file}.tmp" && mv "${timestamp_file}.tmp" "$timestamp_file"
            fi
        fi
    done

    # Parse and update workshop.cfg with mod names
    while IFS= read -r line; do
        # Extract mod ID and name (if present)
        mod_id=$(echo "$line" | awk '{print $1}')
        mod_name=$(echo "$line" | cut -d' ' -f2-)

        # Skip invalid lines
        if [[ ! "$mod_id" =~ ^[0-9]+$ ]]; then
            continue
        fi

        # Get mod name from meta.cpp if not present
        if [[ -z "$mod_name" || "$mod_name" == "$mod_id" ]]; then
            mod_meta_file="${workshopfolder}/$mod_id/meta.cpp"
            if [ -f "$mod_meta_file" ]; then
                mod_name=$(cut -d '"' -f 2 <<< $(grep name "$mod_meta_file"))
            else
                mod_name="Unknown"
            fi
        fi

	# Save the updated line
        updated_workshop_cfg+="${mod_id} ${mod_name}"$'\n'
    done < "$workshop_cfg"

    # Rewrite workshop.cfg if necessary
    if [ -n "$updated_workshop_cfg" ]; then
        echo "$updated_workshop_cfg" > "$workshop_cfg"
        echo "Updated workshop.cfg with mod names."
    fi

 	# Copy key files
	if ls ${SERVER_PATH}/serverfiles/@* 1> /dev/null 2>&1; then
	    printf "\n[ ${green}DayZ${default} ] Copying Mod Keys to Server Keys folder...\n"
	    for keydir in ${SERVER_PATH}/serverfiles/@*/[Kk]eys/ ${SERVER_PATH}/serverfiles/@*/[Kk]ey/; do
	        if [ -d "$keydir" ]; then
	            cp -vu "$keydir"* "${SERVER_PATH}/serverfiles/keys/" > /dev/null 2>&1
	        fi
	    done
	fi
}


fn_backup_dayz(){
    fn_status_dayz

    # Ensure backup directory exists
    if [ ! -d "${SERVER_PATH}/backup" ]; then
        mkdir -p ${SERVER_PATH}/backup &> /dev/null
    fi

    # Get the mission folder name
    missionfolder=$(grep template ${SERVER_PATH}/serverfiles/serverDZ.cfg | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d \  -f3)

    # Format for backup files: missionfolder-Month-Day-Hour-Minute.tar
    backup_file="${SERVER_PATH}/backup/${missionfolder}-$(date +%m-%d-%H-%M).tar"
    profile_backup_file="${SERVER_PATH}/backup/serverprofile-$(date +%m-%d-%H-%M).tar"

    # Create the backup of the mission folder
    if [ "${dayzstatus}" == "0" ]; then
        printf "[ ${green}DayZ${default} ] Creating backup of Missionfolder: ${cyan}${missionfolder}${default}\n"
        tar -cf "$backup_file" -C "${SERVER_PATH}/serverfiles/mpmissions" "${missionfolder}"
	    # Backup the serverprofile directory while excluding .log and .RPT files
	    printf "[ ${green}DayZ${default} ] Creating backup of Serverprofile directory: ${cyan}${SERVER_PATH}/serverprofile${default}\n"
	    tar --exclude='*.log' --exclude='*.RPT' -cf "$profile_backup_file" -C "${HOME}" "serverprofile"      	
    else
        fn_stop_dayz
        fn_start_dayz
    fi

    # Delete backups older than 2 days
    printf "[ ${green}DayZ${default} ] Cleaning up backups older than 2 days...\n"
    find "${SERVER_PATH}/backup" -type f -name "${missionfolder}-*.tar" -mtime +2 -exec rm -f {} \;
    find "${SERVER_PATH}/backup" -type f -name "serverprofile-*.tar" -mtime +2 -exec rm -f {} \;
}


fn_wipe_dayz(){
	missionfolder=$(grep template ${SERVER_PATH}/serverfiles/serverDZ.cfg | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d \  -f3)
	printf "[ ${red}WARNING${default} ] Wiping Players and reset Central Economy state from...\n"
	for seconds in {9..0}; do
		printf "\r\t    Selected Mission: ${cyan}${missionfolder}${default} in ${red}"${seconds}"${default} seconds."
		sleep 1
	done
	printf "\n"
	if [ "${dayzstatus}" == "0" ]; then
		rm -f ${SERVER_PATH}/serverfiles/mpmissions/${missionfolder}/storage_1/players.db
		rm -f ${SERVER_PATH}/serverfiles/mpmissions/${missionfolder}/storage_1/data/*
		printf "[ ${yellow}DayZ${default} ] Player.db and Storage-data wiped!\n"
	else
		fn_stop_dayz
		rm -f ${SERVER_PATH}/serverfiles/mpmissions/${missionfolder}/storage_1/players.db
		rm -f ${SERVER_PATH}/serverfiles/mpmissions/${missionfolder}/storage_1/data/*
		printf "[ ${yellow}DayZ${default} ] Player.db and Storage-data wiped!\n"
		sleep 0.5
		fn_start_dayz
	fi
}

cmd_start=( "st;start" "fn_start_dayz" "Start the server." )
cmd_stop=( "sp;stop" "fn_stop_dayz" "Stop the server." )
cmd_restart=( "r;restart" "fn_restart_dayz" "Restart the server.")
cmd_monitor=( "m;monitor" "fn_monitor_dayz" "Check server status and restart if crashed." )
cmd_console=( "c;console" "fn_console_dayz" "Access server console." )
cmd_install=( "i;install" "fn_install_dayz" "Install steamcmd and DayZ Server-Files." )
cmd_update=( "u;update" "fn_update_dayz" "Check and apply any server updates." )
cmd_validate=( "v;validate" "fn_validate_dayz" "Validate server files with SteamCMD." )
cmd_workshop=( "ws;workshop" "fn_workshop_mods" "Download Mods from Steam Workshop." )
cmd_backup=( "b;backup" "fn_backup_dayz" "Create backup archives of the server (mpmission)." )
cmd_wipe=( "wi;wipe" "fn_wipe_dayz" "Wipe your server data (Player and Storage)." )

### Set specific opt here ###
currentopt=( "${cmd_start[@]}" "${cmd_stop[@]}" "${cmd_restart[@]}" "${cmd_monitor[@]}" "${cmd_console[@]}" "${cmd_install[@]}" "${cmd_update[@]}" "${cmd_validate[@]}" "${cmd_workshop[@]}" "${cmd_backup[@]}" "${cmd_wipe[@]}" )

### Build list of available commands
optcommands=()
index="0"
for ((index="0"; index < ${#currentopt[@]}; index+=3)); do
	cmdamount="$(echo "${currentopt[index]}" | awk -F ';' '{ print NF }')"
	for ((cmdindex=1; cmdindex <= ${cmdamount}; cmdindex++)); do
		optcommands+=( "$(echo "${currentopt[index]}" | awk -F ';' -v x=${cmdindex} '{ print $x }')" )
	done
done

# Shows LinuxGSM usage
fn_opt_usage(){
        printf "\nDayZ - Linux Game Server"
	printf "\nUsage:${lightblue} $0 [command]${default}\n\n"
        printf "${lightyellow}Commands${default}\n"
        # Display available commands
        index="0"
        {
        for ((index="0"; index < ${#currentopt[@]}; index+=3)); do
                # Hide developer commands
                if [ "${currentopt[index+2]}" != "DEVCOMMAND" ]; then
                        echo -e "${cyan}$(echo "${currentopt[index]}" | awk -F ';' '{ print $2 }')\t${default}$(echo "${currentopt[index]}" | awk -F ';' '{ print $1 }')\t|${currentopt[index+2]}"
                fi
        done
        } | column -s $'\t' -t
        exit 1
}

# start functions
fn_checkroot_dayz
check_dependencies
fn_checkscreen

getopt=$1
if [ ! -f "${SERVER_PATH}/steamcmd/steamcmd.sh" ] || [ ! -f "${SERVER_PATH}/serverfiles/DayZServer" ] && [ "${getopt}" != "cfg" ]; then
	printf "[ ${yellow}INFO${default} ] No installed steamcmd and/or serverfiles found!\n"
	chmod u+x ${SERVER_PATH}/dayzserver
	fn_install_dayz
	if [ -f "${SERVER_PATH}/steamcmd/steamcmd.sh" ] && [ -f "${SERVER_PATH}/serverfiles/DayZServer" ]; then
		fn_opt_usage
	fi
	exit
else
	### Check if user commands exist and run corresponding scripts, or display script usage
	if [ -z "${getopt}" ]; then
		fn_opt_usage
	fi
fi

# Command exists
for i in "${optcommands[@]}"; do
	if [ "${i}" == "${getopt}" ] ; then
		# Seek and run command
		index="0"
		for ((index="0"; index < ${#currentopt[@]}; index+=3)); do
			currcmdamount="$(echo "${currentopt[index]}" | awk -F ';' '{ print NF }')"
			for ((currcmdindex=1; currcmdindex <= ${currcmdamount}; currcmdindex++)); do
				if [ "$(echo "${currentopt[index]}" | awk -F ';' -v x=${currcmdindex} '{ print $x }')" == "${getopt}" ]; then
					# Run command
					eval "${currentopt[index+1]}"
                                        exit 1
					break
				fi
			done
		done
	fi
done

# If we're executing this, it means command was not found
echo -e "${red}Unknown command${default}: $0 ${getopt}"
fn_opt_usage
