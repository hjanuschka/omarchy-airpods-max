#!/usr/bin/env bash
# Build and install the AirPods Max daemon: the upstream plugin's daemon plus the patches here.
set -euo pipefail

UPSTREAM_REPO=${UPSTREAM_REPO:-https://github.com/thisisgm/omarchy-pods.git}
UPSTREAM_BASE=${UPSTREAM_BASE:-fff7fec600a5b9a61cdb40e93eccbcceb4b8f824}
WORKTREE=${WORKTREE:-$HOME/.cache/omarchy-airpods-max/omarchy-pods}
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PATCH_DIR=$HERE/patches
BIN_DIR=$HOME/.local/bin
PACKAGES=(qt6-base qt6-declarative qt6-tools cmake ninja ffmpeg libpulse python-evdev)

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

check() {
    local missing=()
    for pkg in "${PACKAGES[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if ((${#missing[@]})); then
        say "missing packages: ${missing[*]}"
        say "  install with: omarchy pkg add ${missing[*]}"
    else
        say "packages: all present"
    fi
    pkg-config --exists libavcodec libavutil \
        && say "libavcodec: $(pkg-config --modversion libavcodec)" \
        || say "libavcodec: MISSING (needed to decode the microphone uplink)"

    if systemctl --user is-active --quiet librepods; then
        say "daemon: running"
        if [[ -x $BIN_DIR/librepods-ctl ]] && command -v jq >/dev/null; then
            "$BIN_DIR/librepods-ctl" status 2>/dev/null \
                | jq -r '"  device: \(.model_name // "unknown"), connected=\(.connected)"' \
                || say "  status: unreadable"
        fi
    else
        say "daemon: not running"
    fi

    local src
    src=$(pactl get-default-source 2>/dev/null || echo unknown)
    say "default input: $src"
    case $src in
        bluez_input.*) say "  WARNING: the AirPods HFP mic is the default input." \
                            "Any app opening it drags playback to 16 kHz mono." ;;
        AirPodsHiRes)  say "  good: the high-resolution source is the default" ;;
    esac
    pactl list sources short 2>/dev/null | grep -q AirPodsHiRes \
        && say "hi-res source: published" || say "hi-res source: absent (pods disconnected, or daemon down)"
}

build() {
    command -v git >/dev/null || fail "git is required"
    pkg-config --exists libavcodec libavutil || fail "libavcodec and libavutil are required"

    mkdir -p -- "$(dirname -- "$WORKTREE")"
    if [[ -d $WORKTREE/.git ]]; then
        git -C "$WORKTREE" fetch --quiet origin
    else
        git clone --quiet "$UPSTREAM_REPO" "$WORKTREE"
    fi

    # Patches apply to the pinned base alone, so the tree is reset to it every run.
    git -C "$WORKTREE" checkout --quiet --detach "$UPSTREAM_BASE"
    git -C "$WORKTREE" reset --hard --quiet "$UPSTREAM_BASE"
    git -C "$WORKTREE" clean -qfd

    shopt -s nullglob
    local patches=("$PATCH_DIR"/*.patch)
    shopt -u nullglob
    ((${#patches[@]})) || fail "no patches in $PATCH_DIR"
    say "applying ${#patches[@]} patch(es) onto ${UPSTREAM_BASE:0:7}"
    # One at a time: git apply validates every input against the tree it starts from, so a
    # patch that builds on the one before it fails when the series is passed in one call.
    for patch in "${patches[@]}"; do
        git -C "$WORKTREE" apply "$patch" \
            || fail "$(basename -- "$patch") does not apply to ${UPSTREAM_BASE:0:7}; see README.patches.md in the fork"
    done

    say "building"
    cmake -S "$WORKTREE/daemon" -B "$WORKTREE/daemon/build" -G Ninja >/dev/null
    cmake --build "$WORKTREE/daemon/build" >/dev/null
    say "testing"
    ctest --test-dir "$WORKTREE/daemon/build" --output-on-failure >/dev/null \
        || fail "the daemon's own test suite failed; refusing to install"

    install -Dm755 "$WORKTREE/daemon/build/librepods" "$BIN_DIR/librepods"
    install -Dm755 "$WORKTREE/daemon/build/librepods-ctl" "$BIN_DIR/librepods-ctl"
    install -Dm644 "$WORKTREE/daemon/librepods.service" \
        "$HOME/.local/share/systemd/user/librepods.service"
    say "installed into $BIN_DIR"

    systemctl --user daemon-reload
    systemctl --user enable --now librepods
    say "daemon: $(systemctl --user is-active librepods)"
}

audio_defaults() {
    # The AirPods HFP mic as the default input is what drags playback into 16 kHz mono.
    local src internal
    src=$(pactl get-default-source 2>/dev/null || true)
    if [[ $src == bluez_input.* ]]; then
        internal=$(pactl list sources short | awk '$2 ~ /^alsa_input/ {print $2; exit}')
        if [[ -n ${internal:-} ]]; then
            pactl set-default-source "$internal"
            say "default input moved off the AirPods HFP mic to $internal"
        else
            say "WARNING: no internal microphone found to fall back to"
        fi
    fi
    # Only takes effect while the pods are connected; it is published by the daemon.
    if pactl list sources short | grep -q AirPodsHiRes; then
        pactl set-default-source AirPodsHiRes
        say "default input set to AirPodsHiRes"
    fi
}

case ${1:-} in
    --check) check ;;
    "")      build; audio_defaults; say; check ;;
    *)       fail "usage: $0 [--check]" ;;
esac
