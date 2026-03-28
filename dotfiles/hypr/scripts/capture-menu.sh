#!/bin/bash
# Unified capture menu for screenshots and screen recording

pidfile="/tmp/wf-recorder.pid"
videodir="$HOME/Videos"
screenshotScript="$HOME/.config/hypr/scripts/screenshot.sh"

# Create Videos directory if it doesn't exist
mkdir -p "$videodir"

# Check if recording is active
if [ -f "$pidfile" ] && ps -p $(cat "$pidfile") > /dev/null 2>&1; then
    is_recording=true
else
    is_recording=false
fi

# Build menu options array
if [ "$is_recording" = true ]; then
    prompt_text="🔴 RECORDING - Press SUPER+PRINT to stop"
    options="📸 Capture Screenshot
🔴 Stop Video Recording"
else
    prompt_text="Select capture mode"
    options="📸 Capture Screenshot
🎥 Record Fullscreen Video
🎥 Record Area Video
🎥 Record Video with Audio"
fi

# Show menu centered on screen
choice=$(echo "$options" | wofi --dmenu --prompt "$prompt_text" --width 400 --height 250 --style "$HOME/.config/wofi/style.css" 2>/dev/null || echo "$options" | rofi -dmenu -i -p "$prompt_text" -no-custom -theme-str 'window {width: 400px; location: center; anchor: center;} entry {enabled: false;}')

case "$choice" in
    "📸 Capture Screenshot")
        "$screenshotScript"
        ;;
    "🎥 Record Fullscreen Video")
        filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"
        wf-recorder -f "$filename" &
        echo $! > "$pidfile"
        notify-send "Screen Recording" "Fullscreen recording started" -i media-record
        ;;
    "🎥 Record Area Video")
        filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"
        geometry=$(slurp)
        if [ -n "$geometry" ]; then
            wf-recorder -g "$geometry" -f "$filename" &
            echo $! > "$pidfile"
            notify-send "Screen Recording" "Area recording started" -i media-record
        fi
        ;;
    "🎥 Record Video with Audio")
        filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"
        wf-recorder --audio -f "$filename" &
        echo $! > "$pidfile"
        notify-send "Screen Recording" "Recording with audio started" -i media-record
        ;;
    "🔴 Stop Video Recording")
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
        fi
        ;;
esac
