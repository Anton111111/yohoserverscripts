#!/bin/bash
SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_PATH/../.env
curl -s "$PLEX_URL/library/sections/all/refresh" -H "X-Plex-Token: $PLEX_TOKEN"