#!/bin/bash
SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_PATH/../.env
if [ -e "$CAFFEINE_FILE_PATH" ]; 
then
	exit 0
else
	exit 1
fi
