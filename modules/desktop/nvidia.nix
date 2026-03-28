{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.nvidia = {
    enable = lib.mkEnableOption "NVIDIA GPU support (proprietary driver)";
  };

  config = lib.mkIf config.services.hecate.desktop.nvidia.enable {
    # ── NVIDIA driver ───────────────────────────────────────────────────
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # Use proprietary driver (not open — open only works on Turing+)
      open = false;

      # Enable modesetting for Wayland
      modesetting.enable = true;

      # Power management (suspend/resume)
      powerManagement.enable = true;

      # nvidia-settings GUI
      nvidiaSettings = true;

      # Use the stable driver branch
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # ── OpenGL ──────────────────────────────────────────────────────────
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # ── Wayland environment variables for NVIDIA ────────────────────────
    environment.sessionVariables = {
      # Required for Hyprland on NVIDIA
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      WLR_NO_HARDWARE_CURSORS = "1";
      NVD_BACKEND = "direct";
    };

    # ── Kernel parameters ───────────────────────────────────────────────
    boot.kernelParams = [ "nvidia-drm.modeset=1" "nvidia-drm.fbdev=1" ];

    # ── CUDA / compute (useful for Ollama) ──────────────────────────────
    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia   # GPU monitoring TUI
      vulkan-tools           # vulkaninfo
      glxinfo                # OpenGL info
    ];
  };
}
