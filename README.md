# noctalia-timer (Alarm Timer)

A [Noctalia](https://noctalia.dev) (v5) countdown timer, modelled on the official `noctalia/timer`
plugin, with one difference: **when time is up, an alert stays on screen and the alarm keeps
ringing until you press Stop.**

- `service.luau` - owns the countdown and the alarm loop, opens the alert
- `alert.luau` - persistent overlay panel ("Time is up!" + Stop button)
- `bar.luau` - bar widget (hourglass / countdown; click opens setup, or stops a ringing alarm)
- `panel.luau` - setup panel with typed duration (`300` -> 3:00, `10300` -> 1:03:00)
- `desktop.luau` - desktop widget with +/- adjusters, progress bar, Stop button
- `sounds/alarm.wav` - bundled beep pattern (generated, no third-party audio)

## How the alert works

The alert is a `[[panel]]` with `persistent = true`, `dismiss_on_outside_click = false` and
`layer = "overlay"`: other panels do not replace it, clicking elsewhere does not close it, and it
is drawn above other windows. It ends when you press **Stop**, click the bar widget, or run
`noctalia msg plugin lazy/alarm-timer:timer all dismiss`. Closing it with Escape also counts as
acknowledging, so the alarm never rings without anything on screen to stop it.

The sound is played with a system player (`pw-play`, falling back to `paplay`) and repeated every
second while ringing. It deliberately does not use `noctalia.sound.*`, which obeys
`[audio] enable_sounds` and stays silent when UI sounds are off.

## Requirements

- Noctalia 5.2.0+ (`plugin_api = 32`; the overlay layer for the alert needs level 30)
- `pw-play` (PipeWire) or `paplay` (PulseAudio) for the alarm sound

## Settings

| Key | Default | |
| --- | --- | --- |
| `sound` | `true` | Loop the alarm until stopped. |
| `sound_file` | empty | Custom `.wav`/`.ogg` instead of the bundled alarm. |
| `sound_player` | `pw-play` | Command that plays a file; `paplay` is the fallback. |
| `notify` | `true` | Also send a normal notification. |

Bar and desktop widgets have their own display options (idle readout, color, progress bar).

## IPC

```bash
noctalia msg plugin lazy/alarm-timer:timer all start 25   # minutes, ignored while running
noctalia msg plugin lazy/alarm-timer:timer all pause      # pause / resume
noctalia msg plugin lazy/alarm-timer:timer all cancel
noctalia msg plugin lazy/alarm-timer:timer all dismiss    # stop the ringing alarm
```

## Install for development

```bash
ln -s "$PWD" ~/.local/share/noctalia/plugins/alarm-timer
noctalia msg plugins enable lazy/alarm-timer
noctalia plugins lint .
```

Add the bar widget from the widget picker (`lazy/alarm-timer:bar`) and/or the desktop widget from
the desktop-widgets editor. `.luau` edits hot-reload; manifest changes need a disable/enable.
Runtime errors land in `~/.cache/noctalia/noctalia.log` (`[ERR] [luau]`).

## Credits

Structure (service + state-driven UI clients) follows the official MIT-licensed `noctalia/timer`
plugin.

## License

[MIT](LICENSE)
