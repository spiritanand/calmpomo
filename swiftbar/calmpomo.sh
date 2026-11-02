#!/bin/bash
# <xbar.title>calmpomo</xbar.title>
# <xbar.desc>Calm pomodoro: icon while focusing, countdown on breaks</xbar.desc>
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>

SELF="$(readlink "$0" || echo "$0")"
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
CLI="$ROOT/bin/calmpomo"
STATE_DIR="${CALMPOMO_STATE_DIR:-$HOME/Library/Application Support/calmpomo}"

item() { echo "$1 | bash=\"$CLI\" param1=$2 terminal=false refresh=false"; }

emit() {
  local icon=$1 text=$2 tip=$3 primary=$4
  echo "~~~"
  echo "$text | sfimage=$icon sfsize=13"
  echo "---"
  echo "$tip | disabled=true"
  echo "---"
  item "$primary" toggle
  item "Skip" skip
  item "Reset" reset
  if [ -e "$STATE_DIR/muted" ]; then item "Unmute sounds" unmute; else item "Mute sounds" mute; fi
}

render() {
  local re='"text":"([0-9]*:?[0-9]*)".*"class":"([a-z-]+)"'
  local last="" line t class out muted
  while IFS= read -r line; do
    if [[ $line =~ $re ]]; then t=${BASH_REMATCH[1]}; class=${BASH_REMATCH[2]}; else continue; fi
    [ "$class" = work-paused ] && [ -e "$STATE_DIR/awaiting" ] && class=waiting
    muted=""; [ -e "$STATE_DIR/muted" ] && muted=" · muted"
    case $class in
      idle) out="circle||Idle$muted|Start focus" ;;
      work) out="circle.fill||Focusing$muted|Pause" ;;
      work-paused) out="pause.circle||Focus paused$muted|Resume focus" ;;
      waiting) out="play.circle||Break's over$muted|Start focus" ;;
      break) out="cup.and.saucer| $t|Break$muted|Pause" ;;
      long-break) out="leaf| $t|Long break$muted|Pause" ;;
      break-paused) out="pause.circle| $t|Break paused$muted|Resume break" ;;
      long-break-paused) out="pause.circle| $t|Long break paused$muted|Resume break" ;;
      *) out="exclamationmark.circle||Unknown state|Start focus" ;;
    esac
    [ "$out" = "$last" ] && continue
    last=$out
    IFS='|' read -r a b c d <<<"$out"
    emit "$a" "$b" "$c" "$d"
  done
}

while :; do
  "$CLI" watch 2>/dev/null | render
  echo "~~~"
  echo " | sfimage=exclamationmark.circle sfsize=13"
  echo "---"
  echo "calmpomo isn't running | disabled=true"
  sleep 5
done
