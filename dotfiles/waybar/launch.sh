#!/bin/bash
# Simple Waybar Launch Script
# Uses custom config and style.css in ~/.config/waybar/

# Kill all running waybar instances
killall waybar 2>/dev/null
pkill waybar 2>/dev/null
sleep 0.3

# Launch waybar with custom config
if [ ! -f $HOME/.cache/waybar-disabled ]; then
    waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css &
fi
