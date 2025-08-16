#!/bin/bash

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

echo "-a: $SERVICE_USER -b: $ADMIN_USER -c: $ADMIN__STEAM_USER_IDS -d: $SERVER_MAP -e: $SERVER_EDITION -f: $SERVER_MODLIST"



 #!/bin/bash

OPTIND=1         # Reset in case getopts has been used previously in the shell.
u=""
p=""

while getopts ":u:p:" opt; do
  case ${opt} in
    u ) STEAM_USERNAME=$OPTARG;;
    p ) STEAM_PASSWORD=$OPTARG;;
    \? ) echo "Usage: script [-u] [-p]";;
  esac
done

echo "-u: $STEAM_USERNAME -p: $STEAM_PASSWORD"



