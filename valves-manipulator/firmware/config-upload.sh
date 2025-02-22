#!/bin/bash

PWD=$(dirname "$0")
source "$PWD/bootstrap.sh"

ensure-dep nodemcu-tool

nodemcu-tool upload config.json setup-completed.txt