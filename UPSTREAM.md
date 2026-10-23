# Upstream

Where each piece of this lives, who owns it, and what is still outstanding.
Run `tools/upstream-status.sh` for the live state; the table below is the map.

## Sent upstream

| PR | Repo | What | State |
|---|---|---|---|
| [#73](https://github.com/thisisgm/omarchy-pods/pull/73) | `thisisgm/omarchy-pods` | Keep the bluez card while a capture is live, so taking the headphones off mid-call no longer ends the call | open |
| [#74](https://github.com/thisisgm/omarchy-pods/pull/74) | `thisisgm/omarchy-pods` | The 64 kHz microphone over AACP, the panel switch, and the call check | open, stacked on #73 |

Both branches live on `hjanuschka/omarchy-pods` as `upstream-pr/capture-guard`
and `upstream-pr/hires-mic`. The working branch with the full, unsquashed
history is `patches/airpods-max-hires`.

## What this work depends on

[kavishdevar/librepods#655](https://github.com/kavishdevar/librepods/pull/655)
by @LuanAdemi, open and unmerged. The AACP command sequence, the SDU framing and
the AAC-ELD parameters are from there; #74 is that work ported from the Rust
daemon to the C++ one, because only one process can hold the AACP channel and
this plugin's panel needs it.

That PR's own TODO still lists a licence and patent review. **That question
travels with every copy of this code, including this repository.** Read it
before promoting any of this widely.

## Carried here, not sent

`patches/*.patch` is the series `install.sh` applies to the pinned base. It is
regenerated from `patches/airpods-max-hires`, so it tracks whatever is in the
fork, including anything upstream has not taken.

The RNNoise filter chain in `config/` is deliberately **not** sent upstream: it
is PipeWire configuration rather than plugin code, and the plugin should not own
a user's audio graph.

## If a PR is merged

1. Bump `UPSTREAM_BASE` in `install.sh` to the merge commit.
2. Regenerate the series: `git format-patch <new-base>..patches/airpods-max-hires -o patches/`.
3. Drop whatever upstream now carries; a patch that applies empty is one to delete.
4. Rebuild through `./install.sh` and run the daemon's own suite before trusting it.

## If a PR is rejected or goes stale

The patch series here keeps working regardless: it is applied to a pinned base,
not to whatever upstream's `main` happens to be today. The cost of staying
un-merged is a rebase each time the base moves, which is what
`README.patches.md` in the fork describes.

## Not verified

The guard in #73 is covered by a unit test of its predicate only. The defect it
fixes was observed in a journal, but the fix has not been driven at runtime:
that needs a live capture and the headphones physically coming off. Nothing here
should describe it as runtime-verified until someone does that.
