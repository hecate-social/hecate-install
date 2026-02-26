{ config, lib, pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" "kubectl" ];
    };

    shellAliases = {
      c = "clear";
      cat = "bat";
      ls = "eza --icons";
      ll = "eza -la --icons";
      lt = "eza --tree --icons";
      v = "nvim";
      lg = "lazygit";
      lzd = "lazydocker";
      fm = "yazi";
      du = "ncdu";
      ping = "gping";
    };

    initExtra = ''
      # FZF Tokyo Night colors
      export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
        --color=fg:#c0caf5,bg:#1a1b26,hl:#ff9e64 \
        --color=fg+:#c0caf5,bg+:#292e42,hl+:#ff9e64 \
        --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff \
        --color=marker:#9ece6a,spinner:#9ece6a,header:#9ece6a \
        --bind 'ctrl-/:toggle-preview' \
        --bind 'ctrl-d:preview-half-page-down' \
        --bind 'ctrl-u:preview-half-page-up'"

      # Zoxide (smart cd)
      eval "$(zoxide init zsh)"

      # Custom functions
      # fe — fuzzy edit file
      fe() {
        local file
        file=$(fzf --preview 'bat --color=always --style=numbers {}' --preview-window=right:60%)
        [ -n "$file" ] && ''${EDITOR:-nvim} "$file"
      }

      # fkill — fuzzy process kill
      fkill() {
        local pid
        pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
        [ -n "$pid" ] && echo "$pid" | xargs kill -''${1:-9}
      }

      # fgb — fuzzy git branch switch
      fgb() {
        local branch
        branch=$(git branch --all | grep -v HEAD | fzf --preview 'git log --oneline -20 {}' | sed 's/.* //' | sed 's#remotes/origin/##')
        [ -n "$branch" ] && git checkout "$branch"
      }

      # Show fastfetch on shell start (only interactive)
      if [[ $- == *i* ]] && command -v fastfetch &>/dev/null; then
        fastfetch --logo small
      fi
    '';
  };

  # FZF integration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
