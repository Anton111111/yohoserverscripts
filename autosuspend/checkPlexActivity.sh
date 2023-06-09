#!/bin/bash
SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_PATH/../.env
mCount=$(curl -s "$PLEX_URL/status/sessions" -H "X-Plex-Token: $PLEX_TOKEN" -H "accept: application/json" | jq '.MediaContainer.size')
if [ $mCount -gt 0 ]; 
then
	exit 0
else
	exit 1
fi
