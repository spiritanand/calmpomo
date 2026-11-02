#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="$HOME/.config/calmpomo"
STATE_DIR="$HOME/Library/Application Support/calmpomo"
AGENTS="$HOME/Library/LaunchAgents"
LABEL=io.github.spiritanand.calmpomo
UID_NUM="$(id -u)"

FOCUS="" BREAK="" LONG="" CYCLES=""
while [ $# -gt 0 ]; do
  case $1 in
    --focus) FOCUS=$2; shift 2 ;;
    --break) BREAK=$2; shift 2 ;;
    --long-break) LONG=$2; shift 2 ;;
    --cycles) CYCLES=$2; shift 2 ;;
    -h|--help)
      echo "usage: ./install.sh [--focus MIN] [--break MIN] [--long-break MIN] [--cycles N]"
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1m==>\033[0m %s\n' "$1"; }

[ "$(uname)" = Darwin ] || { echo "calmpomo's menu bar needs macOS" >&2; exit 1; }
command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh" >&2; exit 1; }
BREW_PREFIX="$(brew --prefix)"

if ! brew list --formula tomat >/dev/null 2>&1; then
  say "Installing tomat"
  brew install jolars/tap/tomat
  brew pin tomat
fi
if [ ! -d /Applications/SwiftBar.app ] && ! brew list --cask swiftbar >/dev/null 2>&1; then
  say "Installing SwiftBar"
  brew install --cask swiftbar
fi
TOMAT="$BREW_PREFIX/opt/tomat/bin/tomat"

say "Writing config to $CONF_DIR/tomat.toml"
mkdir -p "$CONF_DIR" "$STATE_DIR/run"
HOOK="$ROOT/libexec/calmpomo-hook"
if [ -f "$CONF_DIR/tomat.toml" ]; then
  sed -i '' "s#^cmd = \".*calmpomo-hook\"#cmd = \"$HOOK\"#" "$CONF_DIR/tomat.toml"
else
  sed "s#__HOOK__#$HOOK#" "$ROOT/config/tomat.toml" > "$CONF_DIR/tomat.toml"
fi
set_timer() { [ -z "$2" ] || sed -i '' "/^\[timer\]/,/^\[/ s#^$1 = .*#$1 = $2#" "$CONF_DIR/tomat.toml"; }
set_timer work "$FOCUS"
set_timer break "$BREAK"
set_timer long_break "$LONG"
set_timer sessions "$CYCLES"

say "Starting the timer at login"
mkdir -p "$AGENTS"
fill() {
  sed -e "s#__TOMAT__#$TOMAT#" -e "s#__CONF_DIR__#$CONF_DIR#" -e "s#__STATE_DIR__#$STATE_DIR#" "$1" > "$2"
}
fill "$ROOT/launchd/timer.plist" "$AGENTS/$LABEL.plist"
fill "$ROOT/launchd/menubar.plist" "$AGENTS/$LABEL.menubar.plist"
for l in "$LABEL" "$LABEL.menubar"; do
  launchctl bootout "gui/$UID_NUM/$l" 2>/dev/null || true
done
launchctl bootstrap "gui/$UID_NUM" "$AGENTS/$LABEL.plist"

say "Adding the menu bar plugin"
PLUGINS="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
if [ -z "$PLUGINS" ]; then
  PLUGINS="$HOME/.config/swiftbar"
  defaults write com.ameba.SwiftBar PluginDirectory "$PLUGINS"
fi
mkdir -p "$PLUGINS"
ln -sf "$ROOT/swiftbar/calmpomo.sh" "$PLUGINS/calmpomo.sh"
osascript -e 'quit app "SwiftBar"' >/dev/null 2>&1 || true
sleep 1
launchctl bootstrap "gui/$UID_NUM" "$AGENTS/$LABEL.menubar.plist"

say "Linking the calmpomo command"
ln -sf "$ROOT/bin/calmpomo" "$BREW_PREFIX/bin/calmpomo"

for _ in 1 2 3 4 5; do "$ROOT/bin/calmpomo" state 2>/dev/null | grep -qv down && break; sleep 1; done
say "Status: $("$ROOT/bin/calmpomo" status)"

cat <<EOF

Done. One manual step for Raycast:
  Raycast → Settings → Extensions → + → Add Script Directory → $ROOT/raycast
  Then give hotkeys to "Start / Pause Focus" and "Reset Pomodoro".

Timer settings live in $CONF_DIR/tomat.toml ([timer] is re-read on every start).
EOF
