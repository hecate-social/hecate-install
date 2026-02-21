{ config, lib, ... }:

let
  cfg = config.services.hecate;
  user = cfg.user;
  group = cfg.group;
in
{
  options.services.hecate = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "rl";
      description = "User that owns the hecate directory tree.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Group for the hecate directory tree.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/home/${cfg.user}/.hecate";
      description = "Root of the hecate data directory.";
    };
  };

  config = {
    systemd.tmpfiles.rules = [
      # Root
      "d ${cfg.dataDir} 0750 ${user} ${group} -"

      # Daemon namespace
      "d ${cfg.dataDir}/hecate-daemon 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/hecate-daemon/sqlite 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/hecate-daemon/reckon-db 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/hecate-daemon/sockets 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/hecate-daemon/run 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/hecate-daemon/connectors 0750 ${user} ${group} -"

      # Config and secrets
      "d ${cfg.dataDir}/config 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/secrets 0700 ${user} ${group} -"

      # GitOps
      "d ${cfg.dataDir}/gitops 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/gitops/system 0750 ${user} ${group} -"
      "d ${cfg.dataDir}/gitops/apps 0750 ${user} ${group} -"
    ];
  };
}
