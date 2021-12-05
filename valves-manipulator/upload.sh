#/bin/bash

FILE_NAME="init.lua"

# step 1: print file size to console
stat -f%z $FILE_NAME &&\
# step 2: build with local lua compile to ensure there is no syntactic errors
luac -p $FILE_NAME &&\
# step 3: upload file to esp8266
nodemcu-tool upload $FILE_NAME &&\
# step 4: read filesystem information (uploaded filed size is expected to be equal to the one printed at step 1)
nodemcu-tool fsinfo