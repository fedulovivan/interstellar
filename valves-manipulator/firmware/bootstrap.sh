#!/bin/bash

# ensure binary/builtin exist
ensure-dep() {
    for cmd in "$@"
    do
        command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "$cmd should be installed"; exit 1; }
    done
    echo "Prerequisites ... OK"
}

# upload all files
upload-all() {
    nodemcu-tool upload "$@"
    echo "Files uploaded ... OK"
}

# validate uploaded size is equal to local
validate-size() {
    fsinfo=$(nodemcu-tool fsinfo --json)
    for filename in "$@"
    do
        orig_size=$(stat -f%z "$filename")
        uploaded_size=$(echo "$fsinfo" | jq -c ".files[] | select(.name == \"$filename\") | .size")
        if [[ "$orig_size" != "$uploaded_size" ]]; then
            echo "FAILED... for $filename uploaded size $uploaded_size does not equal to original $orig_size"
            exit 1
        fi
    done
    echo "Size validated ... OK"
}

# update verison file
update-version() {
    rev=$(git rev-parse --short HEAD)
    echo -n "$rev" > ./version.txt
}

# enable "exit on error" mode
set -e

# disable nodejs warnings
export NODE_NO_WARNINGS=1