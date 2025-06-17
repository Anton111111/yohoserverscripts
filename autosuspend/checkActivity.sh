#!/bin/bash

SCRIPT_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

$SCRIPT_PATH/checkCaffeine.sh || $SCRIPT_PATH/checkTorrserverActivity.sh || $SCRIPT_PATH/checkPlexActivity.sh || $SCRIPT_PATH/checkQBitorrentActivity.sh
