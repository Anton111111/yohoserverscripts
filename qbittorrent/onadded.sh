#!/bin/bash
SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_PATH/../.env

I=$1

curl -i -X POST --data "hashes=$I" "$QBITTORRENT_URL/api/v2/torrents/toggleSequentialDownload"


