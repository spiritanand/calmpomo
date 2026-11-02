#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Start Focus (Minutes)
# @raycast.mode silent
# @raycast.packageName calmpomo
# @raycast.icon ⏱️
# @raycast.argument1 { "type": "text", "placeholder": "minutes", "optional": true }
exec "$(dirname "$0")/../bin/calmpomo" start "$1"
