#/bin/bash

FILE_NAME="init.lua"

# step 1: print file size to console
INITIAL_SIZE=`stat -f%z $FILE_NAME`
echo "file size $INITIAL_SIZE"

# step 2: verify file with luacheck
luacheck $FILE_NAME
if [ $? -ne 0 ]; then
    echo 'luacheck failed'
    exit 1
fi

# step 3: upload file to esp8266
nodemcu-tool upload $FILE_NAME
if [ $? -ne 0 ]; then
    echo 'upload to nodemcu failed'
    exit 1
fi

# step 4: read filesystem information (uploaded filed size is expected to be equal to the one printed at step 1)
FSINFO=$(nodemcu-tool fsinfo)
if [ $? -ne 0 ]; then
    echo 'reading nodemcu filesystem failed'
    exit 1
fi

UPLOADED_SIZE=$(echo "$FSINFO" | grep $FILE_NAME | grep -Eo "[0-9]{4}")
if [[ "$INITIAL_SIZE" != "$UPLOADED_SIZE" ]]; then
    echo "FAILED... uploaded size $UPLOADED_SIZE does not equal to intial $INITIAL_SIZE"
    exit 1
fi

echo "OK! successfully uploded and verified size"

exit 0