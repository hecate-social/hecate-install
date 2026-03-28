{ config, lib, pkgs, ... }:

{
  options.services.hecate.desktop.dev-tools = {
    enable = lib.mkEnableOption "Developer CLI tools bundle";
  };

  config = lib.mkIf config.services.hecate.desktop.dev-tools.enable {
    # Podman for container development
    virtualisation.podman.enable = true;

    environment.systemPackages = with pkgs; [
      # ── File & directory ──────────────────────────────────────────────
      bat                # cat with syntax highlighting
      eza                # modern ls
      fd                 # modern find
      ripgrep            # modern grep
      fzf                # fuzzy finder
      zoxide             # smart cd
      yazi               # terminal file manager
      ncdu               # disk usage (interactive)
      dust               # disk usage (visual, fast)
      duf                # disk free (pretty)
      tree               # directory tree
      ouch               # universal compress/decompress

      # ── Git ───────────────────────────────────────────────────────────
      git
      delta              # pretty git diffs
      lazygit            # TUI git client

      # ── Containers ────────────────────────────────────────────────────
      lazydocker         # TUI docker/podman client
      docker-compose

      # ── Kubernetes ────────────────────────────────────────────────────
      k9s                # TUI k8s dashboard

      # ── System monitoring ─────────────────────────────────────────────
      htop               # process viewer
      btop               # resource monitor (fancy)
      procs              # modern ps
      bandwhich          # bandwidth per-process

      # ── Network ───────────────────────────────────────────────────────
      curl
      wget
      xh                 # modern httpie/curl (Rust)
      gping              # ping with graph
      doggo              # modern DNS client
      mtr                # traceroute + ping combined
      iperf3             # network throughput testing

      # ── Data processing ───────────────────────────────────────────────
      jq                 # JSON processor
      yq-go              # YAML processor
      sd                 # modern sed
      choose             # modern cut

      # ── Development ───────────────────────────────────────────────────
      direnv             # per-directory environments
      just               # modern make (justfile)
      watchexec          # file watcher → run commands
      hyperfine          # CLI benchmarking
      tokei              # code statistics
      hexyl              # hex viewer

      # ── Multiplexer ──────────────────────────────────────────────────
      tmux
      zellij             # modern tmux alternative

      # ── Docs & help ──────────────────────────────────────────────────
      tealdeer           # tldr pages (fast)
      viddy              # modern watch with diffs

      # ── File manager (GUI) ───────────────────────────────────────────
      nautilus
    ];

    # direnv: hook into shells automatically
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
