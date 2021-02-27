#/bin/bash
stat -f%z init.lua && luac -p init.lua && nodemcu-tool upload init.lua && nodemcu-tool fsinfo