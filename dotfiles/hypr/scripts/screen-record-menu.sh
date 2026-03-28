#!/bin/bash
# Screen recording menu script

pidfile="/tmp/wf-recorder.pid"
videodir="$HOME/Videos"

# Create Videos directory if it doesn't exist
mkdir -p "$videodir"

# Check if recording is active
if [ -f "$pidfile" ] && ps -p $(cat "$pidfile") > /dev/null 2>&1; then
    recording_status="🔴 Stop Recording"
else
    recording_status="⚫ Not Recording"
fi

# Menu options
options="Record Fullscreen\nRecord Area\nRecord with Audio\n$recording_status"

# Show menu
choice=$(echo -e "$options" | rofi -dmenu -i -p "Screen Recording" -theme-str 'window {width: 300px;}')

case "$choice" in
    "Record Fullscreen")
        if [ -f "$pidfile" ]; then
            notify-send "Screen Recording" "Already recording. Stop first." -i dialog-warning
        else
            filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"
            wf-recorder -f "$filename" &
            echo $! > "$pidfile"
            notify-send "Screen Recording" "Fullscreen recording started" -i media-record
        fi
        ;;
    "Record Area")
        if [ -f "$pidfile" ]; then
            notify-send "Screen Recording" "Already recording. Stop first." -i dialog-warning
        else
            filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"
            geometry=$(slurp)
            if [ -n "$geometry" ]; then
                wf-recorder -g "$geometry" -f "$filename" &
                echo $! > "$pidfile"
                notify-send "Screen Recording" "Area recording started" -i media-record
            fi
        fi
        ;;
    "Record with Audio")
        if [ -f "$pidfile" ]; then
            notify-send "Screen Recording" "Already recording. Stop first." -i dialog-warning
        else
            filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"
            wf-recorder --audio -f "$filename" &
            echo $! > "$pidfile"
            notify-send "Screen Recording" "Recording with audio started" -i media-record
        fi
        ;;
    "🔴 Stop Recording")
        if [ -f "$pidfile" ]; then
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
            notify-send "Screen Recording" "No active recording" -i dialog-information
        fi
        ;;
esac
