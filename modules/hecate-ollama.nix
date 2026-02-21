{ config, lib, pkgs, ... }:

let
  cfg = config.services.hecate;
in
{
  options.services.hecate.ollama = {
    enable = lib.mkEnableOption "Ollama LLM inference server";

    backend = lib.mkOption {
      type = lib.types.str;
      default = "ollama";
      description = "LLM backend type (ollama).";
    };

    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:11434";
      description = "Ollama API endpoint URL.";
    };

    exposeNetwork = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to expose Ollama on all interfaces (for inference nodes serving cluster).";
    };

    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Models to pre-load on activation.";
      example = [ "llama3.2" "deepseek-r1" ];
    };

    acceleration = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "cuda" "rocm" ]);
      default = null;
      description = "GPU acceleration backend.";
    };
  };

  config = lib.mkIf cfg.ollama.enable {
    services.ollama = {
      enable = true;
      host = if cfg.ollama.exposeNetwork then "0.0.0.0" else "127.0.0.1";
      loadModels = cfg.ollama.models;
      acceleration = cfg.ollama.acceleration;
    };
  };
}
