#!/bin/bash
# Screen recording toggle with rofi menu
# Mirrors the screenshot.sh UX: SUPER+R opens menu, SUPER+R again stops recording

pidfile="/tmp/wf-recorder.pid"
videodir="$HOME/Videos"
mkdir -p "$videodir"

# If already recording, stop it
if [ -f "$pidfile" ] && ps -p "$(cat "$pidfile")" > /dev/null 2>&1; then
    pid=$(cat "$pidfile")
    kill -INT "$pid"
    rm -f "$pidfile"

    # Wait briefly for file to finalize
    sleep 0.3

    # Find the most recent mp4 in videodir
    latest=$(ls -t "$videodir"/recording_*.mp4 2>/dev/null | head -1)
    if [ -n "$latest" ]; then
        size=$(du -h "$latest" | cut -f1)
        name=$(basename "$latest")
        notify-send "Recording Saved" "$name ($size)" -i video-x-generic
    else
        notify-send "Recording Stopped" "Video saved to ~/Videos" -i video-x-generic
    fi
    exit 0
fi

# Clean up stale pidfile
[ -f "$pidfile" ] && rm -f "$pidfile"

# Get monitor info from hyprctl
focused_monitor=$(hyprctl monitors -j | python3 -c "
import json, sys
monitors = json.load(sys.stdin)
for m in monitors:
    if m['focused']:
        print(f\"{m['name']} {m['x']}x{m['y']} {m['width']}x{m['height']}\")
        break
")

monitor_name=$(echo "$focused_monitor" | awk '{print $1}')
monitor_pos=$(echo "$focused_monitor" | awk '{print $2}')
monitor_size=$(echo "$focused_monitor" | awk '{print $3}')

# Build geometry string for focused monitor: "WxH,X,Y" → wf-recorder wants "X,Y WxH"
mon_x=$(echo "$monitor_pos" | cut -d'x' -f1)
mon_y=$(echo "$monitor_pos" | cut -d'x' -f2)
mon_w=$(echo "$monitor_size" | cut -d'x' -f1)
mon_h=$(echo "$monitor_size" | cut -d'x' -f2)
monitor_geometry="${mon_x},${mon_y} ${mon_w}x${mon_h}"

# Menu options
opt_monitor="Record Active Monitor ($monitor_name)"
opt_area="Record Selected Area"
opt_monitor_audio="Record Monitor + Audio"
opt_area_audio="Record Area + Audio"

choice=$(printf '%s\n' \
    "$opt_monitor" \
    "$opt_area" \
    "$opt_monitor_audio" \
    "$opt_area_audio" \
    | rofi -dmenu -replace -config ~/.config/rofi/config-screenshot.rasi -i -no-show-icons -l 4 -width 30 -p "Screen Recording")

[ -z "$choice" ] && exit 0

filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"

case "$choice" in
    "$opt_monitor")
        wf-recorder -g "$monitor_geometry" -f "$filename" &
        echo $! > "$pidfile"
        notify-send "Recording $monitor_name" "Press SUPER+R to stop" -i media-record
        ;;
    "$opt_area")
        geometry=$(slurp)
        if [ -n "$geometry" ]; then
            wf-recorder -g "$geometry" -f "$filename" &
            echo $! > "$pidfile"
            notify-send "Recording Area" "Press SUPER+R to stop" -i media-record
        fi
        ;;
    "$opt_monitor_audio")
        wf-recorder --audio -g "$monitor_geometry" -f "$filename" &
        echo $! > "$pidfile"
        notify-send "Recording $monitor_name + Audio" "Press SUPER+R to stop" -i media-record
        ;;
    "$opt_area_audio")
        geometry=$(slurp)
        if [ -n "$geometry" ]; then
            wf-recorder --audio -g "$geometry" -f "$filename" &
            echo $! > "$pidfile"
            notify-send "Recording Area + Audio" "Press SUPER+R to stop" -i media-record
        fi
        ;;
esac
