{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;

  # Build the secrets env file content from configured keys
  secretLines = lib.flatten [
    [ "# LLM Provider API Keys" "# Managed by NixOS (hecate-secrets module)" "" ]
    (lib.optional (cfg.secrets.anthropicApiKey != null)
      "ANTHROPIC_API_KEY=${cfg.secrets.anthropicApiKey}")
    (lib.optional (cfg.secrets.openaiApiKey != null)
      "OPENAI_API_KEY=${cfg.secrets.openaiApiKey}")
    (lib.optional (cfg.secrets.googleApiKey != null)
      "GOOGLE_API_KEY=${cfg.secrets.googleApiKey}")
  ];

  generatedSecretsFile = pkgs.writeText "llm-providers.env"
    (lib.concatStringsSep "\n" secretLines);
in
{
  options.services.hecate.secrets = {
    enable = lib.mkEnableOption "hecate LLM API key management";

    anthropicApiKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Anthropic API key. Consider using sops-nix for production.";
    };

    openaiApiKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "OpenAI API key. Consider using sops-nix for production.";
    };

    googleApiKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Google API key. Consider using sops-nix for production.";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to an existing secrets env file. If set, this file is copied
        into the secrets directory instead of generating one from individual keys.
        Use this with sops-nix or agenix for production deployments.
      '';
    };
  };

  config = lib.mkIf cfg.secrets.enable {
    system.activationScripts.hecate-secrets = {
      text =
        let
          sourceFile = if cfg.secrets.secretsFile != null
            then cfg.secrets.secretsFile
            else generatedSecretsFile;
        in ''
          install -m 0600 -o ${cfg.user} -g ${cfg.group} \
            ${sourceFile} \
            ${cfg.dataDir}/secrets/llm-providers.env
        '';
      deps = [ "users" ];
    };
  };
}
