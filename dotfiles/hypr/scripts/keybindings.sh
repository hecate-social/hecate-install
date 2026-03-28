#!/bin/bash
# keybindings.sh — Show all active keybindings in rofi
# Reads live bindings from hyprctl (works with home-manager)

keybinds=""

while IFS= read -r line; do
    # hyprctl binds -j gives JSON, parse with jq
    :
done

# Use hyprctl binds -j for structured output
keybinds=$(hyprctl binds -j 2>/dev/null | jq -r '
    .[] |
    select(.dispatcher != "") |
    (
        (if .modmask == 64 then "SUPER"
         elif .modmask == 65 then "SUPER + SHIFT"
         elif .modmask == 68 then "SUPER + CTRL"
         elif .modmask == 72 then "SUPER + ALT"
         elif .modmask == 69 then "SUPER + CTRL + SHIFT"
         elif .modmask == 0 then ""
         else "MOD(\(.modmask))" end)
        + (if .modmask > 0 then " + " else "" end)
        + .key
        + "\r"
        + .dispatcher
        + (if .arg != "" then " " + .arg else "" end)
    )
' 2>/dev/null)

# Fallback: if hyprctl binds -j not available, parse text output
if [ -z "$keybinds" ]; then
    keybinds=$(hyprctl binds 2>/dev/null | awk '
        /^bind/ {
            gsub(/bind\[.*\] = /, "")
            print
        }
    ')
fi

if [ -z "$keybinds" ]; then
    notify-send "Keybindings" "Could not read keybindings from hyprctl"
    exit 1
fi

echo "$keybinds" | rofi -dmenu -i -markup -eh 2 -replace -p "Keybinds" -config ~/.config/rofi/config-compact.rasi