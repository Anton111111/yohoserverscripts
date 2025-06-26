#!/bin/bash
SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $SCRIPT_PATH/../.env
if [ -s "$CAFFEINE_FILE_PATH" ]; then
	threshold=$(<"$CAFFEINE_FILE_PATH")
	# Validate threshold is a number
	if ! [[ "$threshold" =~ ^[0-9]+$ ]]; then
		exit 1
	fi

	now=$(date +%s)
	if [[ "$(uname)" == "Darwin" || "$(uname)" == *"BSD"* ]]; then
		modTime=$(stat -f %m "$CAFFEINE_FILE_PATH") # macOS or BSD
	else
		modTime=$(stat -c %Y "$CAFFEINE_FILE_PATH") # GNU/Linux
	fi

	# Calculate difference
	diff=$((now - modTime))
	if ((diff <= threshold)); then
		exit 0
	else
		echo "0" >"$CAFFEINE_FILE_PATH"
		exit 1
	fi
else
	exit 1
fi
