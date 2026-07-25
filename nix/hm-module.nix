self: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  shell-default = self.packages.${system}.default;

  cfg = config.programs.illogical-impulse;
in {
  options = with lib; {
    programs.illogical-impulse = {
      enable = mkEnableOption "Enable the illogical-impulse (dots-hyprland) Quickshell shell";
      package = mkOption {
        type = types.package;
        default = shell-default;
        description = "The package of the illogical-impulse shell";
      };

      # Necessary for non-NixOS to handle GPU (since home-manager 25.11).
      # See sdata/dist-nix/README.md in dots-hyprland for background.
      genericLinuxGpu = mkOption {
        type = types.bool;
        default = true;
        description = "Enable targets.genericLinux.enable for non-NixOS GPU access";
      };

      systemd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable the systemd user service for illogical-impulse";
        };
        target = mkOption {
          type = types.str;
          description = "The systemd target that will automatically start illogical-impulse";
          default = config.wayland.systemd.target;
        };
        environment = mkOption {
          type = types.listOf types.str;
          description = "Extra environment variables to pass to the illogical-impulse systemd service";
          default = [];
          example = ["QT_QPA_PLATFORMTHEME=gtk3"];
        };
      };

      settings = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "illogical-impulse config.json settings (~/.config/illogical-impulse/config.json)";
      };
      extraConfig = mkOption {
        type = types.str;
        default = "";
        description = "illogical-impulse extra config written verbatim into config.json before `settings` is merged in";
      };
    };
  };

  config = let
    shell = cfg.package;
  in
    lib.mkIf cfg.enable {
      targets.genericLinux.enable = cfg.genericLinuxGpu;

      systemd.user.services.illogical-impulse = lib.mkIf cfg.systemd.enable {
        Unit = {
          Description = "illogical-impulse Quickshell Shell Service";
          After = [cfg.systemd.target];
          PartOf = [cfg.systemd.target];
          X-Restart-Triggers = lib.mkIf (cfg.settings != {} || cfg.extraConfig != "") [
            "${config.xdg.configFile."illogical-impulse/config.json".source}"
          ];
        };

        Service = {
          Type = "exec";
          ExecStart = "${shell}/bin/illogical-impulse";
          Restart = "on-failure";
          RestartSec = "5s";
          TimeoutStopSec = "5s";
          Environment = ["QT_QPA_PLATFORM=wayland"] ++ cfg.systemd.environment;
          Slice = "session.slice";
        };

        Install = {
          WantedBy = [cfg.systemd.target];
        };
      };

      xdg.configFile."illogical-impulse/config.json" = lib.mkIf (cfg.settings != {} || cfg.extraConfig != "") {
        text = lib.pipe (
          if cfg.extraConfig != ""
          then cfg.extraConfig
          else "{}"
        ) [
          builtins.fromJSON
          (lib.recursiveUpdate cfg.settings)
          builtins.toJSON
        ];
      };

      home.packages = [shell];
    };
}
