#!/bin/bash
# Quick presentation recording shortcut

pidfile="/tmp/wf-recorder.pid"
videodir="$HOME/Videos"

mkdir -p "$videodir"

if [ -f "$pidfile" ] && ps -p $(cat "$pidfile") > /dev/null 2>&1; then
    # Stop recording if already running
    pid=$(cat "$pidfile")
    kill -INT "$pid"
    rm "$pidfile"
    notify-send "Presentation Saved! ✓" "Video saved to ~/Videos" -i video-x-generic -t 4000
else
    # Start presentation recording
    active_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
    notify-send "Presentation Recording" "Starting in 3 seconds..." -i microphone -t 2500
    sleep 3

    filename="$videodir/presentation_$(date +%Y%m%d_%H%M%S).mp4"
    wf-recorder -o "$active_monitor" --audio -f "$filename" &
    echo $! > "$pidfile"
    notify-send "🎤 Recording!" "Presentation with audio\\nPress SUPER+ALT+PRINT to stop" -i media-record -t 4000
fi
