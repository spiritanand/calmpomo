#!/usr/bin/env bash
set -euo pipefail

LABEL=io.github.spiritanand.calmpomo
AGENTS="$HOME/Library/LaunchAgents"
CONF_DIR="$HOME/.config/calmpomo"
STATE_DIR="$HOME/Library/Application Support/calmpomo"

for l in "$LABEL" "$LABEL.menubar"; do
  launchctl bootout "gui/$(id -u)/$l" 2>/dev/null || true
  rm -f "$AGENTS/$l.plist"
done

PLUGINS="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
PLUGINS="${PLUGINS/#\~/$HOME}"
if [ -n "$PLUGINS" ]; then
  rm -f "$PLUGINS/calmpomo.sh"
  if [ "$PLUGINS" = "$HOME/.config/swiftbar" ] && rmdir "$PLUGINS" 2>/dev/null; then
    defaults delete com.ameba.SwiftBar PluginDirectory 2>/dev/null || true
  fi
fi
rm -f "$STATE_DIR"/run/tomat.*
for p in /opt/homebrew /usr/local "$(brew --prefix 2>/dev/null || true)"; do
  [ -n "$p" ] && [ -L "$p/bin/calmpomo" ] && rm -f "$p/bin/calmpomo"
done
if [ -e "$STATE_DIR/.pinned-tomat" ]; then
  brew unpin tomat 2>/dev/null || true
  rm -f "$STATE_DIR/.pinned-tomat"
fi

if [ "${1:-}" = --purge ]; then
  rm -rf "$CONF_DIR" "$STATE_DIR"
  echo "Removed calmpomo, its config and session log."
else
  echo "Removed calmpomo. Kept $CONF_DIR and the session log in $STATE_DIR (use --purge to delete)."
fi
echo "tomat and SwiftBar are still installed: brew uninstall tomat && brew uninstall --cask swiftbar"
