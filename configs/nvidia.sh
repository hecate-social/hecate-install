# /etc/profile.d/hecate-nvidia.sh — NVIDIA Wayland environment
export LIBVA_DRIVER_NAME=nvidia
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export GBM_BACKEND=nvidia-drm
export WLR_NO_HARDWARE_CURSORS=1
export NVD_BACKEND=direct
