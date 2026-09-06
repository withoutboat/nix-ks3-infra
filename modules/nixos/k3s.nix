{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.k3s-infra;

  # Format disabled components into --disable flags
  disableFlags = map (c: "--disable ${c}") cfg.disabledComponents;

  # Build extraFlags
  flannelFlag = optional (cfg.flannelBackend != null) "--flannel-backend=${cfg.flannelBackend}";
  kubeconfigModeFlag = optional (cfg.role == "server" && cfg.kubeconfig.mode != null) "--write-kubeconfig-mode ${cfg.kubeconfig.mode}";
  portFlag = optional (cfg.role == "server" && cfg.port != 6443) "--https-listen-port ${toString cfg.port}";

  allExtraFlags = disableFlags
    ++ flannelFlag
    ++ kubeconfigModeFlag
    ++ portFlag
    ++ cfg.extraFlags;

  extraFlagsStr = concatStringsSep " " allExtraFlags;

  # Firewall rules
  serverTCPPorts = [
    cfg.port # K3s supervisor and Kubernetes API Server (default 6443)
    10250    # Kubelet metrics / logs
  ] ++ optionals cfg.clusterInit [
    2379 2380 # Embedded etcd HA
  ] ++ optionals cfg.firewall.openIngressPorts [
    80 443   # HTTP / HTTPS ingress
  ] ++ cfg.firewall.additionalTCPPorts;

  agentTCPPorts = [
    10250 # Kubelet metrics / logs
  ] ++ optionals cfg.firewall.openIngressPorts [
    80 443
  ] ++ cfg.firewall.additionalTCPPorts;

  flannelUDPPorts =
    if cfg.flannelBackend == "vxlan" then [ 8472 ]
    else if cfg.flannelBackend == "wireguard-native" then [ 51820 51821 ]
    else [];

  allUDPPorts = flannelUDPPorts ++ cfg.firewall.additionalUDPPorts;

  yamlFormat = pkgs.formats.yaml { };
in
{
  options.services.k3s-infra = {
    enable = mkEnableOption "K3s Kubernetes infrastructure service";

    role = mkOption {
      type = types.enum [ "server" "agent" ];
      default = "server";
      description = "K3s node role (server for control-plane + worker, agent for worker node).";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.k3s;
      defaultText = literalExpression "pkgs.k3s";
      description = "The K3s package to use.";
    };

    serverAddr = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://192.168.1.100:6443";
      description = "Address of the K3s server to join (required for agent and secondary servers).";
    };

    token = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Shared cluster join token (consider tokenFile for production).";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/k3s-token";
      description = "Path to file containing cluster join token.";
    };

    clusterInit = mkOption {
      type = types.bool;
      default = false;
      description = "Initialize HA cluster using embedded etcd datastore (server role only).";
    };

    port = mkOption {
      type = types.port;
      default = 6443;
      description = "K3s API server and supervisor port.";
    };

    flannelBackend = mkOption {
      type = types.nullOr (types.enum [ "vxlan" "host-gw" "wireguard-native" "none" ]);
      default = "vxlan";
      description = "Flannel CNI backend. Set to 'none' if deploying third-party CNI (e.g. Cilium).";
    };

    disabledComponents = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "traefik" "servicelb" "local-storage" "metrics-server" ];
      description = "K3s built-in components to disable (passed as --disable <component>).";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "--node-name my-node" "--tls-san 10.0.0.1" ];
      description = "Additional command-line flags passed to K3s.";
    };

    config = mkOption {
      type = types.nullOr (types.attrsOf types.anything);
      default = null;
      description = "Structured declarative config for /etc/rancher/k3s/config.yaml.";
    };

    firewall = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically manage NixOS firewall rules for K3s ports.";
      };

      openIngressPorts = mkOption {
        type = types.bool;
        default = false;
        description = "Open standard HTTP (80) and HTTPS (443) ingress ports.";
      };

      additionalTCPPorts = mkOption {
        type = types.listOf types.port;
        default = [];
        description = "Additional TCP ports to open (e.g., NodePort range).";
      };

      additionalUDPPorts = mkOption {
        type = types.listOf types.port;
        default = [];
        description = "Additional UDP ports to open.";
      };
    };

    kubeconfig = {
      mode = mkOption {
        type = types.nullOr types.str;
        default = "0644";
        description = "File permissions mode for /etc/rancher/k3s/k3s.yaml.";
      };

      setKubeconfigEnv = mkOption {
        type = types.bool;
        default = true;
        description = "Set system-wide KUBECONFIG environment variable pointing to /etc/rancher/k3s/k3s.yaml.";
      };
    };

    tools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install Kubernetes CLI tools (kubectl, helm, k9s) into system packages.";
      };

      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        description = "Additional packages to install alongside cluster tools.";
      };
    };

    manifests = mkOption {
      type = types.attrsOf (types.either types.lines types.path);
      default = {};
      example = literalExpression ''
        {
          "nginx.yaml" = ./manifests/nginx.yaml;
          "namespace.yaml" = ''
            apiVersion: v1
            kind: Namespace
            metadata:
              name: production
          '';
        }
      '';
      description = "Manifests to place into /var/lib/rancher/k3s/server/manifests/ for automatic deployment.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.role == "agent" -> (cfg.serverAddr != null);
        message = "services.k3s-infra.serverAddr must be specified when role is 'agent'.";
      }
      {
        assertion = cfg.role == "agent" -> (cfg.token != null || cfg.tokenFile != null);
        message = "services.k3s-infra.token or tokenFile must be specified when role is 'agent'.";
      }
    ];

    services.k3s = {
      enable = true;
      role = cfg.role;
      package = cfg.package;
      serverAddr = mkIf (cfg.serverAddr != null) cfg.serverAddr;
      token = mkIf (cfg.token != null) cfg.token;
      tokenFile = mkIf (cfg.tokenFile != null) cfg.tokenFile;
      clusterInit = mkIf (cfg.role == "server") cfg.clusterInit;
      extraFlags = extraFlagsStr;
    };

    # Declarative config file if specified
    environment.etc = mkMerge [
      (mkIf (cfg.config != null) {
        "rancher/k3s/config.yaml".source = yamlFormat.generate "k3s-config.yaml" cfg.config;
      })
      # Declarative manifests
      (mkIf (cfg.role == "server" && cfg.manifests != {}) (
        mapAttrs' (name: content:
          nameValuePair "rancher/k3s/server/manifests/${name}" (
            if builtins.isPath content then { source = content; }
            else { text = content; }
          )
        ) cfg.manifests
      ))
    ];

    # Firewall configuration
    networking.firewall = mkIf cfg.firewall.enable {
      allowedTCPPorts = if cfg.role == "server" then serverTCPPorts else agentTCPPorts;
      allowedUDPPorts = allUDPPorts;
    };

    # Environment variables
    environment.sessionVariables = mkIf (cfg.role == "server" && cfg.kubeconfig.setKubeconfigEnv) {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    # CLI tools
    environment.systemPackages = mkIf cfg.tools.enable (
      [
        pkgs.kubectl
        pkgs.kubernetes-helm
        pkgs.k9s
      ] ++ cfg.tools.extraPackages
    );
  };
}
