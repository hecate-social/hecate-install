{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate.branding;

  # Plymouth theme derivation
  plymouth-theme-hecate = pkgs.stdenv.mkDerivation {
    pname = "plymouth-theme-hecate";
    version = "0.1.0";
    src = ../branding/plymouth/hecate;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/plymouth/themes/hecate
      cp -r $src/* $out/share/plymouth/themes/hecate/
    '';
  };

  # GRUB theme derivation
  grub-theme-hecate = pkgs.stdenv.mkDerivation {
    pname = "grub-theme-hecate";
    version = "0.1.0";
    src = ../branding/grub/hecate;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/grub/themes/hecate
      cp -r $src/* $out/grub/themes/hecate/
    '';
  };
in
{
  options.services.hecate.branding = {
    enable = lib.mkEnableOption "hecatOS branding (Plymouth + GRUB + quiet boot)";
  };

  config = lib.mkIf cfg.enable {
    # ── Plymouth (boot splash) ─────────────────────────────────────────────
    boot.plymouth = {
      enable = true;
      theme = "hecate";
      themePackages = [ plymouth-theme-hecate ];
    };

    # ── GRUB theming ───────────────────────────────────────────────────────
    boot.loader.grub = {
      theme = lib.mkDefault "${grub-theme-hecate}/grub/themes/hecate";
    };

    # ── Quiet boot (hide kernel messages, show Plymouth) ───────────────────
    boot.kernelParams = [ "quiet" "splash" "loglevel=3" "rd.udev.log_priority=3" ];
    boot.consoleLogLevel = 0;
    boot.initrd.verbose = false;
  };
}
