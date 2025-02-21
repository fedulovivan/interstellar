#!/bin/bash

PWD=$(dirname "$0")
source "$PWD/bootstrap.sh"

ensure-dep nodemcu-tool

# disable nodejs warnings
export NODE_NO_WARNINGS=1

nodemcu-tool terminal