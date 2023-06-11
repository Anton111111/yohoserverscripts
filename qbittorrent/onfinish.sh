#!/bin/bash
SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_PATH/../.env

I=$1
N=$2
L=$3

cd /home/anton/yohoserverbot && node ./dist/torrent.js --action=finish --name "$N" --category "$L"
curl "$QBITTORRENT_URL/api/v2/torrents/delete?hashes=$I&deleteFiles=false"
$SCRIPT_PATH/../plex/libraryRefreshAll.sh

