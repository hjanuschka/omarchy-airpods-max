# AirPods Max on Omarchy

Everything needed to run **AirPods Max (2nd gen, A3454)** on Omarchy / Arch with
Hyprland: battery and noise control in the bar, pause when you take them off,
and calls that do not wreck playback.

Measured on one machine: AirPods Max 2 (`model_int 12`, `A3454`) over a TP-Link
RTL8761BU adapter, Omarchy, PipeWire 1.6.9, WirePlumber, Qt 6.12.

## Status

| Feature | State |
|---|---|
| Battery (headset and case) in the bar | works |
| Noise control: ANC, Transparency, Adaptive | works |
| Pause when taken off the head, resume when worn | works |
| High-fidelity playback (A2DP) | works |
| Calls without dropping playback to 16 kHz mono | works, with the audio defaults below |
| Taking them off mid-call no longer ends the call | patched here, see `patches/` |
| **AirPods microphone at 64 kHz while A2DP keeps playing** | works, in the daemon, with the UI running |
| Microphone arms itself when an app records, disarms when it stops | works |
| Switch and state line in the bar popup | works |
| `testbed/callcheck.py`, a pre-meeting check | works |

## The constraint that explains everything

Over the standard Bluetooth profiles a card cannot carry a high-quality sink and
a microphone at once. On this device:

| Profile | What it gives |
|---|---|
| `a2dp-sink-sbc` | SBC 328 kbps playback, **no microphone** |
| `a2dp-sink` | AAC 256 kbps playback, no microphone |
| `headset-head-unit` | 16 kHz mSBC, microphone, **playback drops to it** |
| `headset-head-unit-cvsd` | 8 kHz, microphone, worse |

So any app that opens the AirPods microphone drags the whole card into
`headset-head-unit`, and music turns into that muffled "call mode". macOS is
bound by the same profiles.

The exception is not a profile. Apple's AACP channel can carry a
high-resolution microphone stream **while A2DP playback continues untouched**.
That is what [docs/hires-mic.md](docs/hires-mic.md) covers.

## Install

```bash
./install.sh --check     # report what is present, change nothing
./install.sh             # build and install the daemon, unit, and audio defaults
```

What it does:

1. checks the build and runtime packages
2. clones or updates the `omarchy-pods` fork at the pinned upstream base
3. applies the patches in `patches/`
4. builds the daemon and runs its test suite
5. installs `librepods`, `librepods-ctl` and the user unit, then starts it
6. points the default input away from the AirPods (see below)

It does not install the bar widget itself. That is the upstream plugin:

```bash
omarchy plugin add https://github.com/hjanuschka/omarchy-pods --enable
```

## Before a meeting

```bash
python3 testbed/callcheck.py     # needs pyside6
```

It says Ready or Not ready, names the input, output, card profile and whether
the microphone is streaming, shows a live level meter, and records four seconds
and plays them back so you hear what the far side will hear. It changes nothing
unless you press "Use the AirPods mic".

## Audio defaults, and why they matter

**Never leave the AirPods as the default input.** If `pactl get-default-source`
is `bluez_input.<mac>`, the next app that opens a microphone switches the card to
`headset-head-unit` and your playback degrades. `install.sh` points the default
input at the internal microphone instead:

```bash
pactl set-default-source alsa_input.<your-internal-mic>
```

For calls, take the microphone from another device (internal mic, webcam) and
leave the AirPods on A2DP for output. This is the supported arrangement until the
AACP microphone lands in the daemon.

If you had a `module-echo-cancel` source whose `source_master` is the AirPods
input, drop it: it can only exist on a headset profile, so it guarantees the
hijack.

## Known limits

- **One owner for the AACP channel.** Only one process can hold the L2CAP link,
  which is why the microphone is ported into this daemon rather than run beside
  it. Do not run the upstream Rust daemon at the same time.
- **The call patch is test-green, not runtime-verified.** See `patches/`.
- **No panel control for the microphone yet.** It works through the default-input
  selection and arms itself; there is no row in the popup and no `supports_*` key
  for it in the status file.
- `install.sh` was written and exercised on one machine. Treat the first run on
  another as a review, not as a trusted script.

## Updating later

Pinned refs live at the top of `install.sh`:

| Component | Upstream | Pinned base |
|---|---|---|
| omarchy-pods | `thisisgm/omarchy-pods` | `fff7fec` (plugin 1.3.6) |
| librepods (Rust, high-res mic) | `kavishdevar/librepods` branch `linux/rust` | `672e65a` |
| high-res mic patch | `kavishdevar/librepods` PR 655 | `99b0e58` |

To move to a newer upstream: bump the base, re-apply `patches/`, rebuild, run the
suite. Each fork also carries its own `README.patches.md` with the same
information and the exact `git rebase --onto` invocation.

## Credits

The AirPods work is other people's: `kavishdevar/librepods` for the AAP/AACP
protocol and the daemon, `thisisgm/omarchy-pods` for the Omarchy plugin and the
hardened fork, and @LuanAdemi for the high-resolution microphone implementation
in PR 655. This repository is the glue, the measurements, and one bug fix.
