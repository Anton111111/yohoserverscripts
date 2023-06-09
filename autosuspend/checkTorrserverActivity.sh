#!/bin/bash
SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_PATH/../.env
tCount=$(curl -s -X POST "$TORRSERVER_URL/torrents" -H "Content-Type: application/json" -d '{"action":"list"}' -u "$TORRSERVER_USERNAME:$TORRSERVER_PASSWORD" | jq 'map(select(.stat != 5)) | length')
if [ $tCount -gt 0 ]; 
then
	exit 0
else
	exit 1
fi
