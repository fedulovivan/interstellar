#!/bin/bash

# funcctions
ensure() {
    cmd=$1
    command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "$cmd should be installed"; exit 1; }
}

# disable nodejs warnings
export NODE_NO_WARNINGS=1

# main lua program
main_lua="init.lua"

# sanity checks
ensure "stat"
ensure "jq"
ensure "luacheck"
ensure "nodemcu-tool"

# step 1: save and print file size to console
orig_size=$(stat -f%z $main_lua)
echo "$main_lua size is ${orig_size} bytes"

# step 2: verify file with luacheck
if ! luacheck $main_lua; then
    echo "luacheck failed"
    exit 1
fi

# step 3: upload file to esp8266
if ! nodemcu-tool upload $main_lua; then
    echo "upload to esp8266 failed"
    exit 1
fi

# step 4: read filesystem information 
# uploaded filed size is expected to be equal to the one, obtained at step 1
# prompt: using jq find a size of file with name init.lua from the json
uploaded_size=$(nodemcu-tool fsinfo --json | jq -c '.files[] | select(.name == "init.lua") | .size')
if [ $? -ne 0 ]; then
    echo "reading esp8266 filesystem failed"
    exit 1
fi
if [[ "$orig_size" != "$uploaded_size" ]]; then
    echo "uploaded size $uploaded_size does not equal to original $orig_size failed"
    exit 1
fi

echo "OK! Successfully uploded and verified size"
exit 0