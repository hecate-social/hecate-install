#!/bin/bash
# Waybar recording status indicator

pidfile="/tmp/wf-recorder.pid"

format_duration() {
    local seconds=$1
    printf "%02d:%02d" $((seconds / 60)) $((seconds % 60))
}

while true; do
    if [ -f "$pidfile" ] && ps -p $(cat "$pidfile") > /dev/null 2>&1; then
        # Recording is active - calculate duration
        pid=$(cat "$pidfile")
        start_time=$(ps -p "$pid" -o lstart= 2>/dev/null | date -f - +%s 2>/dev/null)
        current_time=$(date +%s)

        if [ -n "$start_time" ]; then
            duration=$((current_time - start_time))
            time_str=$(format_duration $duration)
            echo "{\"text\": \"🔴 $time_str\", \"class\": \"recording\", \"tooltip\": \"Recording in progress\\nDuration: $time_str\\nPress SUPER+SHIFT+PRINT to stop\"}"
        else
            echo '{"text": "🔴 REC", "class": "recording", "tooltip": "Recording in progress\\nPress SUPER+SHIFT+PRINT to stop"}'
        fi
    else
        # Not recording
        echo '{"text": "📹", "class": "idle", "tooltip": "Press SUPER+PRINT to capture"}'
    fi
    sleep 1
done
