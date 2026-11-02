# calmpomo

A calm pomodoro timer for the macOS menu bar, started with a hotkey.

While you focus, the menu bar shows only a small dot, so there's no clock counting down at you. Click it if you want to see how long is left. Breaks show a countdown. Soft chimes mark focus, breaks, and the end of a break. When a break ends, calmpomo waits for you to start the next focus.

calmpomo isn't a new app. It's a short recipe that wires together free tools:

- [tomat](https://github.com/jolars/tomat) runs the timer (MIT, Rust)
- [SwiftBar](https://github.com/swiftbar/SwiftBar) draws the menu bar item (MIT)
- a `calmpomo` command you can trigger from anything: [Raycast](https://www.raycast.com), Alfred, Hammerspoon, AeroSpace, skhd, Shortcuts, or a terminal

The glue is a few shell scripts and four sounds generated in code. It replaces [pomo-cli](https://github.com/spiritanand/pomo-cli), an earlier Node.js prototype.

## What you see

| Menu bar | Meaning |
|---|---|
| ◯ | Idle |
| ● | Focusing (no countdown on purpose) |
| ⏸ | Paused |
| ☕ 14:59 | Short break |
| 🍃 44:59 | Long break |
| ▶ | Break's over: start the next focus when you're ready |
| ⚠ | The timer isn't running |

The icons are SF Symbols, so they match the rest of your menu bar. Click the item to see the state and time left (for example `Focusing · 47:12 left`) and to Start/Pause, Skip, Reset or Mute.

## Sounds

| Moment | Sound |
|---|---|
| Focus starts | two soft notes, rising |
| Break starts | two soft notes, falling |
| Long break starts | the break sound, twice |
| Break ends | one quiet note |

The sounds sit at about -26 LUFS, except the break-end note, which is kept quieter at -31 LUFS. None of them has energy in the harsh 2–5 kHz range. `scripts/gen-sounds.py` rebuilds them (needs ffmpeg); there are no audio samples to license. Mute everything with `calmpomo mute`.

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- Something that can run a command on a hotkey (optional: the menu bar works on its own)

## Install

```
git clone https://github.com/spiritanand/calmpomo ~/calmpomo
cd ~/calmpomo
./install.sh
```

The installer:

1. installs tomat (`jolars/tap/tomat`, pinned) and SwiftBar if they're missing
2. writes `~/.config/calmpomo/tomat.toml`
3. adds two login agents: one runs the timer, one opens SwiftBar
4. links the menu bar plugin into SwiftBar's plugin folder
5. links `calmpomo` into your Homebrew `bin`

The installed pieces link back to your clone, so keep it where it is. If you move it, run `./install.sh` again from the new place.

Pick your own durations at install time:

```
./install.sh --focus 90 --break 15 --long-break 45 --cycles 2
```

The defaults are 25-minute focus, 5-minute break, 15-minute long break, and a long break after every 4 focus blocks.

Check it works:

```
calmpomo status     # Idle
calmpomo toggle     # Focus started, and the menu bar dot fills in
calmpomo reset
```

## Hotkeys

Everything goes through one command, so any tool that can run a shell command works. You only really need two keys:

| Action | Command | Suggested key |
|---|---|---|
| Start / pause / resume | `calmpomo toggle` | Ctrl+Cmd+K |
| Reset to idle | `calmpomo reset` | Ctrl+Cmd+; |
| Skip to the next phase | `calmpomo skip` | Ctrl+Cmd+' |

Toggle is one key for everything. It starts focus when idle, starts the next focus after a break, and otherwise pauses or resumes. Skip does nothing while calmpomo is waiting for you after a break: press toggle instead.

Every command prints one short line (`Focus started`, `Paused`, `Break · 12:30 left`) that works well as a pop-up message, and exits with a non-zero code when something went wrong, for example when the timer isn't running.

Apps started from the Dock or at login don't always see Homebrew's `bin` on their `PATH`, so the examples below use the full path. That's `/opt/homebrew/bin/calmpomo` on Apple Silicon and `/usr/local/bin/calmpomo` on Intel; `which calmpomo` tells you which.

### Raycast

calmpomo ships ready-made Raycast script commands.

1. Open Raycast settings (Cmd+comma) → **Extensions** → **+** → **Add Script Directory**.
2. Pick the `raycast` folder inside your clone.
3. Give hotkeys to **Start / Pause Focus**, **Reset Pomodoro** and, if you like, **Skip Pomodoro Phase**.

The other commands are:

- **Pomodoro Status** shows the current state and time left, for example `Focusing · 47:12 left`
- **Mute / Unmute Pomodoro**
- **Start Focus (Minutes)** starts a fresh focus of the length you type and keeps it until the next reset

### Hammerspoon

In `~/.hammerspoon/init.lua`:

```lua
local function pomo(cmd)
  return function() hs.alert.show(hs.execute("/opt/homebrew/bin/calmpomo " .. cmd)) end
end
hs.hotkey.bind({"ctrl", "cmd"}, "k", pomo("toggle"))
hs.hotkey.bind({"ctrl", "cmd"}, ";", pomo("reset"))
hs.hotkey.bind({"ctrl", "cmd"}, "'", pomo("skip"))
```

### AeroSpace

In `~/.aerospace.toml`, under `[mode.main.binding]`:

```toml
ctrl-cmd-k = 'exec-and-forget /opt/homebrew/bin/calmpomo toggle'
ctrl-cmd-semicolon = 'exec-and-forget /opt/homebrew/bin/calmpomo reset'
ctrl-cmd-quote = 'exec-and-forget /opt/homebrew/bin/calmpomo skip'
```

### skhd

In `~/.skhdrc`:

```
ctrl + cmd - k : /opt/homebrew/bin/calmpomo toggle
ctrl + cmd - 0x29 : /opt/homebrew/bin/calmpomo reset
ctrl + cmd - 0x27 : /opt/homebrew/bin/calmpomo skip
```

### Shortcuts, Alfred, Keyboard Maestro, BetterTouchTool

Make an action that runs a shell script, put `/opt/homebrew/bin/calmpomo toggle` in it, and give it a hotkey. Repeat for `reset` and `skip`.

- **Shortcuts**: add a **Run Shell Script** action, then use **Add Keyboard Shortcut** in the shortcut's details.
- **Alfred** (Powerpack): a workflow with a **Hotkey** trigger connected to a **Run Script** action.
- **Keyboard Maestro**: a macro with a **Hot Key** trigger and an **Execute Shell Script** action.
- **BetterTouchTool**: a keyboard shortcut whose action is **Execute Terminal Command**.

### Terminal only

Skip hotkeys altogether and type `calmpomo toggle`. Short aliases help:

```sh
alias pomo='calmpomo toggle' pomoreset='calmpomo reset'
```

## Command line

```
calmpomo toggle         start, pause or resume
calmpomo start [MIN]    start focus, or begin the next focus after a break
                        (MIN starts a fresh focus of that length, kept until reset)
calmpomo pause
calmpomo skip           jump to the next phase
calmpomo reset          stop and go back to idle
calmpomo status         state and time left
calmpomo mute | unmute | toggle-mute
calmpomo log [N]        last N session log lines
```

## Settings

Edit `~/.config/calmpomo/tomat.toml`. The `[timer]` section is read when a cycle starts from idle, so run `calmpomo reset` to apply an edit mid-cycle:

```toml
[timer]
work = 90
break = 15
long_break = 45
sessions = 2
auto_advance = "to-break"
```

`auto_advance = "to-break"` is what makes breaks start by themselves while focus waits for you. Changes to the hooks need a timer restart:

```
launchctl kickstart -k gui/$(id -u)/io.github.spiritanand.calmpomo
```

## Session log

Every start, pause, break and reset is appended to `~/Library/Application Support/calmpomo/sessions.log` as tab-separated lines. The log keeps the last 365 days and never grows past 1 MB.

## Troubleshooting

- **⚠ in the menu bar, or `calmpomo isn't running`**: the timer's login agent stopped. Run `./install.sh` again; if it still fails, it prints the last line of `~/Library/Application Support/calmpomo/daemon.log`.
- **No menu bar item**: open SwiftBar once and check that its plugin folder contains `calmpomo.sh`. macOS may hide menu bar items when the bar is full.
- **Hotkey does nothing**: run the same command in a terminal. If it works there, use the full path in your hotkey tool.
- **No sound**: check `calmpomo status` doesn't say `muted`, and that your output volume is up.

## Uninstall

```
./uninstall.sh            # keep config and log
./uninstall.sh --purge    # remove them too
```

tomat and SwiftBar stay installed; the script prints the commands to remove them. Remove the Raycast script directory or your hotkey bindings by hand.

## How it works

```
hotkey tool ────┐
SwiftBar click ─┼─> bin/calmpomo ──> tomat daemon (login agent)
terminal ───────┘                         │
                                          ├─ hooks ──> libexec/calmpomo-hook ──> sounds, log, "break's over" flag
                                          └─ watch ──> swiftbar/calmpomo.sh ──> menu bar
```

tomat keeps time by the wall clock and saves its state after every change, so a restart or a reboot picks up where it left off.

## Linux

Not yet. tomat already runs on Linux, so most of the work is the menu bar, sounds and installer. See the [Linux issues](https://github.com/spiritanand/calmpomo/issues?q=is%3Aissue+label%3Alinux).

## License

MIT OR Apache-2.0
