#!/bin/bash
# User-friendly capture menu with improved UX

pidfile="/tmp/wf-recorder.pid"
videodir="$HOME/Videos"
screenshotScript="$HOME/.config/hypr/scripts/screenshot.sh"

# Create Videos directory if it doesn't exist
mkdir -p "$videodir"

# Function to start recording with countdown
start_recording() {
    local output="$1"
    local geometry="$2"

    # Show countdown
    for i in 3 2 1; do
        notify-send -t 800 "Recording starts in..." "$i" -i camera-video
        sleep 1
    done

    filename="$videodir/recording_$(date +%Y%m%d_%H%M%S).mp4"

    if [ -n "$geometry" ]; then
        wf-recorder -g "$geometry" -f "$filename" &
    else
        wf-recorder -o "$output" -f "$filename" &
    fi

    echo $! > "$pidfile"
    notify-send "Recording Started! 🔴" "Press SUPER+SHIFT+PRINT to stop" -i media-record -t 3000
}

# Check if recording is active
if [ -f "$pidfile" ] && ps -p $(cat "$pidfile") > /dev/null 2>&1; then
    # If recording, show option to stop
    choice=$(printf "🔴 Stop Recording\n📸 Take Screenshot\n📁 Open Recordings Folder" | wofi --dmenu --prompt "🔴 Currently Recording" --width 350 --height 180 --cache-file=/dev/null)

    case "$choice" in
        "🔴 Stop Recording")
            pid=$(cat "$pidfile")
            kill -INT "$pid"
            rm "$pidfile"
            notify-send "Recording Saved! ✓" "Video saved to ~/Videos" -i video-x-generic -t 3000
            ;;
        "📸 Take Screenshot")
            "$screenshotScript"
            ;;
        "📁 Open Recordings Folder")
            xdg-open "$videodir"
            ;;
    esac
else
    # Get current active monitor info
    active_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
    active_desc=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .description' | cut -d'(' -f1)

    # Not recording, show main options
    choice=$(printf "📸 Screenshot\n🎤 Record Presentation (with audio)\n🎥 Record This Screen\n🖥️  Choose Screen\n✂️  Select Area\n📁 Open Recordings" | wofi --dmenu --prompt "Capture Menu" --width 450 --height 280 --cache-file=/dev/null)

    case "$choice" in
        "📸 Screenshot")
            "$screenshotScript"
            ;;
        "🎤 Record Presentation (with audio)")
            # Presentation mode with audio
            notify-send "Presentation Recording" "Starting in 3 seconds - Get ready!" -i microphone -t 2500
            sleep 3
            filename="$videodir/presentation_$(date +%Y%m%d_%H%M%S).mp4"
            wf-recorder -o "$active_monitor" --audio -f "$filename" &
            echo $! > "$pidfile"
            notify-send "🎤 Recording Presentation!" "Audio + Video recording\\nPress SUPER+SHIFT+PRINT to stop" -i media-record -t 4000
            ;;
        "🎥 Record This Screen"*)
            start_recording "$active_monitor"
            ;;
        "🖥️  Choose Screen")
            # Build monitor list with descriptions
            monitor_list=$(hyprctl monitors -j | jq -r '.[] | .name + " - " + .description' | sed 's/ (.*)//')
            monitor=$(echo "$monitor_list" | wofi --dmenu --prompt "Select monitor to record" --width 500 --height 200 --cache-file=/dev/null)
            if [ -n "$monitor" ]; then
                # Extract just the monitor name (DP-1, DP-2, etc)
                monitor_name=$(echo "$monitor" | awk '{print $1}')
                start_recording "$monitor_name"
            fi
            ;;
        "✂️  Select Area")
            notify-send "Select Recording Area" "Click and drag to select area" -i input-mouse -t 2000
            geometry=$(slurp)
            if [ -n "$geometry" ]; then
                start_recording "" "$geometry"
            fi
            ;;
        "📁 Open Recordings")
            xdg-open "$videodir"
            ;;
    esac
fi
