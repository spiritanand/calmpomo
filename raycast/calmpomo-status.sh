#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Pomodoro Status
# @raycast.mode silent
# @raycast.packageName calmpomo
# @raycast.icon ℹ️

exec "$(dirname "$0")/../bin/calmpomo" status
