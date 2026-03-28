{ config, lib, pkgs, ... }:

{
  # Fastfetch config
  xdg.configFile."fastfetch/config.jsonc".source = ../dotfiles/fastfetch/config.jsonc;

  # All logo variants (read-only, managed by home-manager)
  xdg.configFile."fastfetch/logos/flame-crown.txt".source = ../dotfiles/fastfetch/logos/flame-crown.txt;
  xdg.configFile."fastfetch/logos/flowing-flame.txt".source = ../dotfiles/fastfetch/logos/flowing-flame.txt;
  xdg.configFile."fastfetch/logos/geometric-h.txt".source = ../dotfiles/fastfetch/logos/geometric-h.txt;
  xdg.configFile."fastfetch/logos/twin-torches.txt".source = ../dotfiles/fastfetch/logos/twin-torches.txt;
  xdg.configFile."fastfetch/logos/minimal-sigil.txt".source = ../dotfiles/fastfetch/logos/minimal-sigil.txt;
  xdg.configFile."fastfetch/logos/neon-wordmark.txt".source = ../dotfiles/fastfetch/logos/neon-wordmark.txt;
  xdg.configFile."fastfetch/logos/torch-minimal.txt".source = ../dotfiles/fastfetch/logos/torch-minimal.txt;
  xdg.configFile."fastfetch/logos/fire-diamond.txt".source = ../dotfiles/fastfetch/logos/fire-diamond.txt;

  # Default logo — created via activation so users can change it with hecate-logo-select
  # home-manager xdg.configFile creates read-only nix store symlinks, so we use
  # activation to create a mutable symlink that the user can freely replace.
  home.activation.fastfetchDefaultLogo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    logo_link="${config.xdg.configHome}/fastfetch/logo.txt"
    logo_dir="${config.xdg.configHome}/fastfetch/logos"
    if [ ! -e "$logo_link" ]; then
      ln -sf "$logo_dir/flame-crown.txt" "$logo_link"
    fi
  '';
}
