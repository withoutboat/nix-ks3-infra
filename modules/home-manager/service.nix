{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.k3s-infra;

  k3sPkg = if pkgs.stdenv.isLinux then pkgs.k3s else pkgs.emptyDirectory;

  disableFlags = map (c: "--disable ${c}") cfg.disabledComponents;

  serverArgs = [
    "${cfg.package}/bin/k3s"
    "server"
  ] ++ optional cfg.rootless "--rootless"
    ++ [
      "--data-dir" cfg.dataDir
      "--write-kubeconfig" cfg.kubeconfig.path
      "--write-kubeconfig-mode" "0644"
      "--https-listen-port" (toString cfg.port)
    ]
    ++ disableFlags
    ++ optional (cfg.token != null) "--token ${cfg.token}"
    ++ optional (cfg.tokenFile != null) "--token-file ${cfg.tokenFile}"
    ++ optional (cfg.serverAddr != null) "--server ${cfg.serverAddr}"
    ++ cfg.extraFlags;

  agentArgs = [
    "${cfg.package}/bin/k3s"
    "agent"
  ] ++ optional cfg.rootless "--rootless"
    ++ [
      "--data-dir" cfg.dataDir
      "--server" cfg.serverAddr
    ]
    ++ optional (cfg.token != null) "--token ${cfg.token}"
    ++ optional (cfg.tokenFile != null) "--token-file ${cfg.tokenFile}"
    ++ cfg.extraFlags;

  k3sArgs = if cfg.role == "server" then serverArgs else agentArgs;

  startScript = pkgs.writeShellScript "k3s-infra-start" ''
    set -euo pipefail
    mkdir -p "${cfg.dataDir}" "$(dirname "${cfg.kubeconfig.path}")"
    exec ${concatStringsSep " " k3sArgs}
  '';

  k3sUp = pkgs.writeShellScriptBin "k3s-up" ''
    set -euo pipefail
    mkdir -p "${cfg.dataDir}" "$(dirname "${cfg.kubeconfig.path}")"
    if command -v systemctl >/dev/null 2>&1 && [ -d "/run/user/$(id -u)/systemd" ]; then
      echo "Starting K3s user service via systemctl..."
      systemctl --user start k3s-infra.service
      echo "K3s service started. Kubeconfig: ${cfg.kubeconfig.path}"
      echo "To check status: systemctl --user status k3s-infra.service"
    else
      echo "Starting K3s rootless in foreground..."
      exec ${startScript}
    fi
  '';

  k3sDown = pkgs.writeShellScriptBin "k3s-down" ''
    set -euo pipefail
    if command -v systemctl >/dev/null 2>&1 && [ -d "/run/user/$(id -u)/systemd" ]; then
      echo "Stopping K3s user service..."
      systemctl --user stop k3s-infra.service
      echo "K3s service stopped."
    else
      echo "Stopping K3s processes..."
      pkill -f "${cfg.package}/bin/k3s" || true
      echo "Stopped."
    fi
  '';

  extraBinPackages = with pkgs; [
    coreutils
    findutils
    gnugrep
    gnused
    iproute2
    iptables
    kmod
    procps
    util-linux
    which
  ] ++ (optionals (builtins.hasAttr "rootlesskit" pkgs) [ pkgs.rootlesskit ])
    ++ (optionals (builtins.hasAttr "slirp4netns" pkgs) [ pkgs.slirp4netns ])
    ++ (optionals (builtins.hasAttr "fuse-overlayfs" pkgs) [ pkgs.fuse-overlayfs ]);
in
{
  options.services.k3s-infra = {
    enable = mkEnableOption "minimal K3s rootless Kubernetes service for user session";

    package = mkOption {
      type = types.package;
      default = k3sPkg;
      defaultText = literalExpression "pkgs.k3s";
      description = "The K3s package to use.";
    };

    role = mkOption {
      type = types.enum [ "server" "agent" ];
      default = "server";
      description = "Node role (server or agent).";
    };

    rootless = mkOption {
      type = types.bool;
      default = true;
      description = "Run K3s in rootless mode (recommended and required for unprivileged user).";
    };

    dataDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.local/share/k3s";
      description = "Data directory for rootless K3s state.";
    };

    port = mkOption {
      type = types.port;
      default = 6443;
      description = "HTTPS API listen port.";
    };

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Server address to join (required for agent role).";
    };

    token = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Cluster join token.";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to token file.";
    };

    disabledComponents = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "traefik" "servicelb" "local-storage" "metrics-server" ];
      description = "K3s built-in components to disable.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "--snapshotter=native" ];
      description = "Additional command-line flags passed to K3s.";
    };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start K3s systemd user service on user login.";
    };

    kubeconfig = {
      path = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.kube/config";
        description = "Where K3s should write the kubeconfig file.";
      };

      setKubeconfigEnv = mkOption {
        type = types.bool;
        default = true;
        description = "Export KUBECONFIG session variable pointing to services.k3s-infra.kubeconfig.path.";
      };
    };

    helperScripts = mkOption {
      type = types.bool;
      default = true;
      description = "Install k3s-up and k3s-down helper CLI scripts.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "services.k3s-infra daemon requires Linux. On macOS, consider running K3s inside a Linux VM or container.";
      }
      {
        assertion = cfg.role == "agent" -> (cfg.serverAddr != null);
        message = "services.k3s-infra.serverAddr must be specified when role is 'agent'.";
      }
    ];

    home.packages = (
      [ cfg.package ]
      ++ optionals cfg.helperScripts [ k3sUp k3sDown ]
    );

    home.sessionVariables = mkIf cfg.kubeconfig.setKubeconfigEnv {
      KUBECONFIG = cfg.kubeconfig.path;
    };

    systemd.user.services.k3s-infra = mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "K3s lightweight Kubernetes (user rootless service)";
        Documentation = [ "https://k3s.io" ];
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        Type = "simple";
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "PATH=${makeBinPath ([ cfg.package ] ++ extraBinPackages)}:/run/current-system/sw/bin"
        ];
        ExecStart = "${startScript}";
        Restart = "on-failure";
        RestartSec = "10s";
        LimitNOFILE = 1048576;
        LimitNPROC = "infinity";
        LimitCORE = "infinity";
        TasksMax = "infinity";
        Delegate = "yes";
      };

      Install = mkIf cfg.autoStart {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
