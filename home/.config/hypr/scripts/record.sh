#!/bin/sh
# record.sh toggle|status — screen recording with hardware (VA-API) H.264 encoding.
pidfile="${XDG_RUNTIME_DIR:-/tmp}/twilight-record.pid"

running() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

case "$1" in
status)
    running && echo recording || echo idle ;;
toggle)
    if running; then
        kill -INT "$(cat "$pidfile")"
        rm -f "$pidfile"
        exit 0
    fi
    dir="$(xdg-user-dir VIDEOS)/Recordings"
    mkdir -p "$dir"
    file="$dir/Recording_$(date +%Y%m%d_%H%M%S).mp4"
    out=$(hyprctl activeworkspace -j 2>/dev/null | sed -n 's/.*"monitor": *"\([^"]*\)".*/\1/p' | head -n1)
    wf-recorder ${out:+-o "$out"} -c h264_vaapi -d /dev/dri/renderD128 --audio -f "$file" >/dev/null 2>&1 &
    echo $! > "$pidfile"
    wait $!
    rm -f "$pidfile"
    notify-send -a "Screen recording" -i video-x-generic "Recording saved" "$(basename "$file")" ;;
*)
    echo "usage: $0 toggle|status" >&2; exit 2 ;;
esac
