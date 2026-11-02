#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Reset Pomodoro
# @raycast.mode silent
# @raycast.packageName calmpomo
# @raycast.icon 🔄

exec "$(dirname "$0")/../bin/calmpomo" reset
