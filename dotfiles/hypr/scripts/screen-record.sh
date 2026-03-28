#!/bin/bash
# Screen recording toggle script using wf-recorder

pidfile="/tmp/wf-recorder.pid"
videodir="$HOME/Videos"

# Create Videos directory if it doesn't exist
mkdir -p "$videodir"

if [ -f "$pidfile" ]; then
    # Stop recording
    pid=$(cat "$pidfile")
    if ps -p "$pid" > /dev/null 2>&1; then
        kill -INT "$pid"
        rm "$pidfile"
        notify-send "Screen Recording" "Recording stopped and saved" -i video-x-generic
    else
        rm "$pidfile"
        notify-send "Screen Recording" "Recording process not found" -i dialog-error
    fi
else
    # Start recording
    filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"
    wf-recorder -f "$filename" &
    echo $! > "$pidfile"
    notify-send "Screen Recording" "Recording started" -i media-record
fi
