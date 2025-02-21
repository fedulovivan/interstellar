#!/bin/bash

PWD=$(dirname "$0")
source "$PWD/bootstrap.sh"

# update verison file
update-version

# sanity checks
ensure-dep jq git stat luacheck nodemcu-tool

# run luacheck for all files
luacheck ./*.lua
echo "Checked sources ... OK"

# upload files
# upload-all init.lua wifi.lua
# config.json
upload-all version.txt ./*.lua

# validate-size
# validate-size init.lua wifi.lua
# config.json
# shellcheck disable=SC2035
validate-size version.txt *.lua

echo "Successfully uploded and validated all files"
exit 0