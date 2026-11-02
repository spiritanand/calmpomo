#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Start / Pause Focus
# @raycast.mode silent
# @raycast.packageName calmpomo
# @raycast.icon 🍅

exec "$(dirname "$0")/../bin/calmpomo" toggle
