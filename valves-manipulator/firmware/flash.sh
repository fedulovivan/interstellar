#!/bin/bash

PWD=$(dirname "$0")
source "$PWD/bootstrap.sh"

ensure-dep esptool.py

PORT=$(jq ".port" .nodemcutool -r)
BAUDRATE=$(jq ".baudrate" .nodemcutool -r)
esptool.py --baud "$BAUDRATE" --port "$PORT" write_flash 0x0000 ./nodemcu-dev-11-modules-2021-12-16-18-33-39-integer.bin