#!/usr/bin/bash

SHC_STATUS=$(which shc > /dev/null; echo $?)
if [ $SHC_STATUS -ne 0 ]; then
    echo -e "\nError: missing shc binary..."
    exit 4
fi

convert_to_binary() {
    SCRIPT_NAME="aro-flp-network.sh"
    BINARY_NAME="$(echo "$SCRIPT_NAME" | sed 's/.sh//')"

    shc -f $SCRIPT_NAME -r -o ./lab_binaries/${BINARY_NAME}
    rm -f ./${SCRIPT_NAME}.x.c > /dev/null 2>&1
}

convert_to_binary

exit 0