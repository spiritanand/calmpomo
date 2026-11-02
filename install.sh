#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="$HOME/.config/calmpomo"
CONF="$CONF_DIR/tomat.toml"
STATE_DIR="$HOME/Library/Application Support/calmpomo"
AGENTS="$HOME/Library/LaunchAgents"
LABEL=io.github.spiritanand.calmpomo
UID_NUM="$(id -u)"

die() { echo "install.sh: $1" >&2; exit 2; }
say() { printf '\033[1m==>\033[0m %s\n' "$1"; }
duration() { [[ $2 =~ ^[0-9]+([.][0-9]+)?$ ]] && [[ ! $2 =~ ^0+([.]0*)?$ ]] || die "$1 needs a positive number of minutes"; }

WORK="" BREAK="" LONG="" CYCLES=""
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help)
      echo "usage: ./install.sh [--focus MIN] [--break MIN] [--long-break MIN] [--cycles N]"
      exit 0 ;;
    --focus|--break|--long-break|--cycles) [ $# -ge 2 ] || die "$1 needs a value" ;;
    *) die "unknown option: $1" ;;
  esac
  case $1 in
    --focus) duration "$1" "$2"; WORK=$2 ;;
    --break) duration "$1" "$2"; BREAK=$2 ;;
    --long-break) duration "$1" "$2"; LONG=$2 ;;
    --cycles) [[ $2 =~ ^[1-9][0-9]*$ ]] || die "--cycles needs a whole number of 1 or more"; CYCLES=$2 ;;
  esac
  shift 2
done

[ "$(uname)" = Darwin ] || die "calmpomo's menu bar needs macOS"
command -v brew >/dev/null || die "Homebrew is required: https://brew.sh"
case $ROOT in *'"'*|*'\'*) die "move calmpomo to a folder whose path has no quotes or backslashes" ;; esac
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

say "Writing config to $CONF"
mkdir -p "$CONF_DIR" "$STATE_DIR"
# tomat refuses a runtime dir that others can write to
[ -d "$STATE_DIR/run" ] && chmod 700 "$STATE_DIR/run"
SRC="$CONF"
[ -f "$CONF" ] || SRC="$ROOT/config/tomat.toml"
TMP="$(mktemp "$CONF_DIR/.tomat.XXXXXX")"
HOOK="$ROOT/libexec/calmpomo-hook" WORK="$WORK" BREAK="$BREAK" LONG="$LONG" CYCLES="$CYCLES" \
  python3 -I - "$SRC" "$TMP" <<'PY'
import os, re, sys
try:
    import tomllib
except ImportError:
    tomllib = None
src, dst = sys.argv[1], sys.argv[2]
hook = os.environ["HOOK"]
text = open(src).read()
text = text.replace("__HOOK__", hook)
text = re.sub(r'^cmd = ".*calmpomo-hook"', lambda _: f'cmd = "{hook}"', text, flags=re.M)
lines, out, in_timer, seen = text.splitlines(), [], False, set()
want = {k: os.environ[e] for k, e in
        [("work", "WORK"), ("break", "BREAK"), ("long_break", "LONG"), ("sessions", "CYCLES")]
        if os.environ[e]}
def flush():
    blanks = 0
    while out and not out[-1].strip():
        out.pop()
        blanks += 1
    out.extend(f"{k} = {v}" for k, v in want.items() if k not in seen)
    out.extend([""] * blanks)
for line in lines:
    if line.startswith("["):
        if in_timer:
            flush()
        in_timer = line.strip() == "[timer]"
    elif in_timer:
        m = re.match(r"\s*([A-Za-z_]+)\s*=", line)
        if m and m.group(1) in want:
            seen.add(m.group(1))
            line = f"{m.group(1)} = {want[m.group(1)]}"
    out.append(line)
if in_timer:
    flush()
text = "\n".join(out) + "\n"
if tomllib:
    tomllib.loads(text)
open(dst, "w").write(text)
PY
mv "$TMP" "$CONF"

say "Starting the timer at login"
mkdir -p "$AGENTS"
fill() {
  sed -e "s|__TOMAT__|$TOMAT|" -e "s|__CONF_DIR__|$CONF_DIR|" -e "s|__STATE_DIR__|$STATE_DIR|" "$1" > "$2"
}
fill "$ROOT/launchd/timer.plist" "$AGENTS/$LABEL.plist"
fill "$ROOT/launchd/menubar.plist" "$AGENTS/$LABEL.menubar.plist"
for l in "$LABEL" "$LABEL.menubar"; do
  launchctl bootout "gui/$UID_NUM/$l" 2>/dev/null || true
done
launchctl bootstrap "gui/$UID_NUM" "$AGENTS/$LABEL.plist"

say "Adding the menu bar plugin"
PLUGINS="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
PLUGINS="${PLUGINS/#\~/$HOME}"
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

for _ in 1 2 3 4 5; do [ "$("$ROOT/bin/calmpomo" state)" != down ] && break; sleep 1; done
if [ "$("$ROOT/bin/calmpomo" state)" = down ]; then
  echo "The timer didn't start. Last daemon log line:" >&2
  tail -n 1 "$STATE_DIR/daemon.log" >&2 2>/dev/null || true
  exit 1
fi
say "Status: $("$ROOT/bin/calmpomo" status)"

cat <<EOF

Done. One manual step for Raycast:
  Raycast → Settings → Extensions → + → Add Script Directory → $ROOT/raycast
  Then give hotkeys to "Start / Pause Focus" and "Reset Pomodoro".

Timer settings live in $CONF.
They apply the next time a focus starts from idle; run "calmpomo reset" to apply them mid-cycle.
EOF
