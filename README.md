# calmpomo

A calm pomodoro timer for the macOS menu bar, started from a Raycast hotkey.

While you focus, the menu bar shows only a small dot, so there's no clock counting down at you. Breaks show a countdown. Soft chimes mark focus, breaks, and the end of a break. When a break ends, calmpomo waits for you to start the next focus.

calmpomo isn't a new app. It's a short recipe that wires together three free tools:

- [tomat](https://github.com/jolars/tomat) runs the timer (MIT, Rust)
- [SwiftBar](https://github.com/swiftbar/SwiftBar) draws the menu bar item (MIT)
- [Raycast](https://www.raycast.com) script commands give you hotkeys

The glue is a few shell scripts and three sounds generated in code.

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

The icons are SF Symbols, so they match the rest of your menu bar. Click the item for Start/Pause, Skip, Reset and Mute.

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
- Raycast, for the hotkeys (optional: the menu bar and the `calmpomo` command work without it)

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

Pick your own durations at install time:

```
./install.sh --focus 90 --break 15 --long-break 45 --cycles 2
```

The defaults are 25-minute focus, 5-minute break, 15-minute long break, and a long break after every 4 focus blocks.

## Set up the hotkeys in Raycast

1. Open Raycast settings (Cmd+comma) → **Extensions** → **+** → **Add Script Directory**.
2. Pick the `raycast` folder inside your calmpomo clone.
3. Give hotkeys to the commands you want. A setup that works well:

| Command | Hotkey |
|---|---|
| Start / Pause Focus | Ctrl+Cmd+K |
| Reset Pomodoro | Ctrl+Cmd+; |
| Skip Pomodoro Phase | Ctrl+Cmd+' |

Other commands: **Pomodoro Status**, **Mute / Unmute Pomodoro**, and **Start Focus (Minutes)**, which starts a fresh focus of that length and keeps it until the next reset.

Start / Pause is one key for everything. It starts focus when idle, starts the next focus after a break, and otherwise pauses or resumes. Skip does nothing while calmpomo is waiting for you after a break: press Start / Pause instead.

Any hotkey tool works instead of Raycast: bind your keys to `calmpomo toggle` and `calmpomo reset`.

## Command line

```
calmpomo toggle         start, pause or resume
calmpomo start [MIN]    start focus, or begin the next focus after a break
                        (MIN starts a fresh focus of that length, kept until reset)
calmpomo pause
calmpomo skip           jump to the next phase
calmpomo reset          stop and go back to idle
calmpomo status
calmpomo mute | unmute
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

## Uninstall

```
./uninstall.sh            # keep config and log
./uninstall.sh --purge    # remove them too
```

tomat and SwiftBar stay installed; the script prints the commands to remove them.

## How it works

```
Raycast hotkey ─┐
SwiftBar click ─┼─> bin/calmpomo ──> tomat daemon (login agent)
terminal ───────┘                         │
                                          ├─ hooks ──> libexec/calmpomo-hook ──> sounds, log, "break's over" flag
                                          └─ watch ──> swiftbar/calmpomo.sh ──> menu bar
```

tomat keeps time by the wall clock and saves its state after every change, so a restart or a reboot picks up where it left off.

## License

MIT OR Apache-2.0
