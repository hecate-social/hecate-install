# /etc/profile.d/hecate.sh — hecatOS environment variables
# Wayland/Hyprland session
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland

# Qt Wayland
export QT_QPA_PLATFORM="wayland;xcb"
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_QPA_PLATFORMTHEME=qt5ct

# GTK/GDK
export GDK_BACKEND="wayland,x11"

# SDL
export SDL_VIDEODRIVER=wayland

# Clutter
export CLUTTER_BACKEND=wayland

# Firefox
export MOZ_ENABLE_WAYLAND=1

# Electron
export ELECTRON_OZONE_PLATFORM_HINT=auto

# Editor
export EDITOR=nvim
export VISUAL=nvim
