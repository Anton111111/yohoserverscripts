#!/bin/bash
SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_PATH/../.env
dCount=$(curl -s "$QBITTORRENT_URL/api/v2/torrents/info?filter=downloading" | jq length)
pCount=$(curl -s "$QBITTORRENT_URL/api/v2/torrents/info?filter=paused" | jq length)
tCount=$((dCount-pCount))
if [ $tCount -gt 0 ]; 
then
	exit 0
else
	exit 1
fi
