{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.k3s-infra;

  packages = (
    optionals cfg.tools.kubectl.enable [ pkgs.kubectl ]
    ++ optionals cfg.tools.helm.enable [ pkgs.kubernetes-helm ]
    ++ optionals cfg.tools.k9s.enable [ pkgs.k9s ]
    ++ optionals cfg.tools.opentofu.enable [ pkgs.opentofu ]
    ++ optionals cfg.tools.terraform.enable [ pkgs.terraform ]
    ++ cfg.tools.extraPackages
  );

  defaultAliases = {
    k = "kubectl";
    kgp = "kubectl get pods";
    kgpa = "kubectl get pods -A";
    kga = "kubectl get all";
    kgn = "kubectl get nodes";
    kgs = "kubectl get svc";
    kgi = "kubectl get ingress";
    kd = "kubectl describe";
    kdp = "kubectl describe pod";
    kl = "kubectl logs";
    klf = "kubectl logs -f";
    kex = "kubectl exec -it";
    kdel = "kubectl delete";
    kapply = "kubectl apply -f";
    tf = "tofu";
  };
in
{
  options.programs.k3s-infra = {
    enable = mkEnableOption "K3s user tooling and Kubernetes environment";

    tools = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install Kubernetes, Helm, k9s, and OpenTofu tools into user profile.";
      };

      kubectl.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install kubectl CLI.";
      };

      helm.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install Helm package manager.";
      };

      k9s.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install k9s terminal UI.";
      };

      opentofu.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install OpenTofu (open-source Terraform fork).";
      };

      terraform.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Install HashiCorp Terraform CLI.";
      };

      extraPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        example = literalExpression "[ pkgs.stern pkgs.kubectx ]";
        description = "Additional packages to include in user environment.";
      };
    };

    kubeconfig = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Manage kubeconfig configuration.";
      };

      path = mkOption {
        type = types.str;
        default = ".kube/config";
        description = "Relative path within home directory for kubeconfig (default: .kube/config).";
      };

      symlinkSource = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/etc/rancher/k3s/k3s.yaml";
        description = "System path to symlink to kubeconfig.path (uses mkOutOfStoreSymlink).";
      };

      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Nix store path to use as kubeconfig.";
      };

      content = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Literal string content to write to kubeconfig.path.";
      };

      setKubeconfigEnv = mkOption {
        type = types.bool;
        default = false;
        description = "Set KUBECONFIG session variable to the configured kubeconfig.";
      };
    };

    shellAliases = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Add helpful kubectl and infrastructure aliases to user shell.";
      };

      extraAliases = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional shell aliases to add.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = mkIf cfg.tools.enable packages;

    home.file = mkIf cfg.kubeconfig.enable (mkMerge [
      (mkIf (cfg.kubeconfig.symlinkSource != null) {
        "${cfg.kubeconfig.path}".source = config.lib.file.mkOutOfStoreSymlink cfg.kubeconfig.symlinkSource;
      })
      (mkIf (cfg.kubeconfig.source != null) {
        "${cfg.kubeconfig.path}".source = cfg.kubeconfig.source;
      })
      (mkIf (cfg.kubeconfig.content != null) {
        "${cfg.kubeconfig.path}".text = cfg.kubeconfig.content;
      })
    ]);

    home.sessionVariables = mkIf (cfg.kubeconfig.enable && cfg.kubeconfig.setKubeconfigEnv) {
      KUBECONFIG =
        if cfg.kubeconfig.symlinkSource != null then
          cfg.kubeconfig.symlinkSource
        else if cfg.kubeconfig.source != null then
          toString cfg.kubeconfig.source
        else
          "${config.home.homeDirectory}/${cfg.kubeconfig.path}";
    };

    home.shellAliases = mkIf cfg.shellAliases.enable (defaultAliases // cfg.shellAliases.extraAliases);
  };
}
