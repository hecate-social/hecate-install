{
  description = "hecatOS — NixOS-based distribution for the Hecate mesh";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:zen-browser/desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, disko, zen-browser }:
    let
      # Overlay that pulls erlang_28 from nixpkgs-unstable
      erlang28Overlay = final: prev: {
        erlang_28 = (import nixpkgs-unstable { system = prev.system; }).erlang_28;
      };

      # Zen Browser overlay
      zenBrowserOverlay = final: prev: {
        zen-browser = zen-browser.packages.${prev.system}.default or null;
      };

      # Helper to make a NixOS configuration for a given role and hardware
      mkSystem = { role, hardware ? "generic-x86", system ? "x86_64-linux", extraModules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (./configurations + "/${role}.nix")
            (./hardware + "/${hardware}.nix")
          ] ++ extraModules;
        };

      # Desktop configuration requires home-manager
      mkDesktop = { hardware ? "generic-x86", system ? "x86_64-linux", extraModules ? [ ] }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            { nixpkgs.overlays = [ zenBrowserOverlay ]; }
            home-manager.nixosModules.home-manager
            ./configurations/desktop.nix
            (./hardware + "/${hardware}.nix")
          ] ++ extraModules;
        };

      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      # ── NixOS Configurations ───────────────────────────────────────────
      # Use: nixos-rebuild switch --flake .#standalone
      nixosConfigurations = {
        standalone = mkSystem {
          role = "standalone";
          hardware = "generic-x86";
        };

        cluster = mkSystem {
          role = "cluster";
          hardware = "generic-x86";
        };

        inference = mkSystem {
          role = "inference";
          hardware = "generic-x86";
        };

        workstation = mkSystem {
          role = "workstation";
          hardware = "generic-x86";
        };

        # ── Desktop (Hyprland daily-driver) ─────────────────────────────
        desktop = mkDesktop {
          hardware = "generic-x86";
        };

        # ── Beam nodes (native Erlang + XFCE + xrdp) ──────────────────
        # Site A: beam00 + beam01 (cluster with host00.lab)
        # Site B: beam02 (standalone)
        # Site C: beam03 (standalone)

        beam00 = mkSystem {
          role = "beam-native";
          hardware = "beam-node";
          extraModules = [
            disko.nixosModules.disko
            ./disko/beam-node-nixos-no-bulk1.nix  # beam00: 1x HDD only
            { nixpkgs.overlays = [ erlang28Overlay ]; }
            {
              networking.hostName = "beam00";
              services.hecate.cluster = {
                cookie = "site_a_cluster_cookie";
                peers = [ "beam01.lab" ];
              };
            }
          ];
        };

        beam01 = mkSystem {
          role = "beam-native";
          hardware = "beam-node";
          extraModules = [
            disko.nixosModules.disko
            ./disko/beam-node-nixos.nix
            { nixpkgs.overlays = [ erlang28Overlay ]; }
            {
              networking.hostName = "beam01";
              services.hecate.cluster = {
                cookie = "site_a_cluster_cookie";
                peers = [ "beam00.lab" ];
              };
            }
          ];
        };

        beam02 = mkSystem {
          role = "beam-native";
          hardware = "beam-node";
          extraModules = [
            disko.nixosModules.disko
            ./disko/beam-node-nixos.nix
            { nixpkgs.overlays = [ erlang28Overlay ]; }
            {
              networking.hostName = "beam02";
              services.hecate.cluster = {
                cookie = "site_b_cluster_cookie";
                peers = [ ];
              };
            }
          ];
        };

        beam03 = mkSystem {
          role = "beam-native";
          hardware = "beam-node";
          extraModules = [
            disko.nixosModules.disko
            ./disko/beam-node-nixos.nix
            { nixpkgs.overlays = [ erlang28Overlay ]; }
            {
              networking.hostName = "beam03";
              services.hecate.cluster = {
                cookie = "site_c_cluster_cookie";
                peers = [ ];
              };
            }
          ];
        };
      };

      # ── Packages ───────────────────────────────────────────────────────
      packages.x86_64-linux = {
        # Branded live desktop ISO — "Try + Install" experience
        # Boots into full Hyprland desktop with "Install hecatOS" shortcut
        # Use: nix build .#iso
        iso = let
          isoSystem = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              { nixpkgs.overlays = [ zenBrowserOverlay ]; }
              home-manager.nixosModules.home-manager
              ./configurations/live-desktop.nix
              ./hardware/generic-x86.nix
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-base.nix"
              {
                isoImage.isoBaseName = "hecatos-live";
                isoImage.volumeID = "HECATOS";
                boot.loader.efi.canTouchEfiVariables = nixpkgs.lib.mkForce false;
              }
            ];
          };
        in isoSystem.config.system.build.isoImage;

        # Headless unattended installer ISO — plug in, auto-detect, wipe, install
        # Use: nix build .#installer-iso
        installer-iso = let
          isoSystem = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              disko.nixosModules.disko
              ./configurations/installer.nix
              ./hardware/generic-x86.nix
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              {
                isoImage.isoBaseName = "hecatos-installer";
                isoImage.volumeID = "HECATOS_INST";
                boot.loader.efi.canTouchEfiVariables = nixpkgs.lib.mkForce false;

                # Include disko + nixos-install tools
                environment.systemPackages = let pkgs = pkgsFor "x86_64-linux"; in [
                  pkgs.nixos-install-tools
                ];
              }
            ];
          };
        in isoSystem.config.system.build.isoImage;

        default = self.packages.x86_64-linux.iso;

        hecate-reconciler = (pkgsFor "x86_64-linux").callPackage ./packages/hecate-reconciler.nix { };
        hecate-cli = (pkgsFor "x86_64-linux").callPackage ./packages/hecate-cli.nix { };
        hecate-install = (pkgsFor "x86_64-linux").callPackage ./packages/hecate-install-script.nix { };
      };

      # ── Checks (NixOS VM tests) ────────────────────────────────────────
      # Use: nix flake check   or   nix build .#checks.x86_64-linux.boot-test
      checks.x86_64-linux =
        let
          pkgs = pkgsFor "x86_64-linux";
        in
        {
          boot-test = import ./tests/boot-test.nix { inherit pkgs; };
          plugin-test = import ./tests/plugin-test.nix { inherit pkgs; };
          firstboot-test = import ./tests/firstboot-test.nix { inherit pkgs; };
          desktop-test = import ./tests/desktop-test.nix {
            inherit pkgs;
            home-manager = home-manager;
          };
          installer-test = import ./tests/installer-test.nix { inherit pkgs; };
          live-desktop-test = import ./tests/live-desktop-test.nix {
            inherit pkgs;
            home-manager = home-manager;
          };
        };
    };
}
