{
  description = "Nix infrastructure and modules for lightweight Kubernetes (K3s)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };
      });
    in
    {
      # NixOS system modules
      nixosModules = {
        k3s = import ./modules/nixos;
        default = self.nixosModules.k3s;
      };

      # Home Manager modules
      homeManagerModules = {
        k3s = import ./modules/home-manager;
        default = self.homeManagerModules.k3s;
      };

      # Development shells for operator / developer workstations
      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.mkShell {
          name = "nix-ks3-infra-shell";

          buildInputs = with pkgs; [
            kubectl
            kubernetes-helm
            k9s
            opentofu
            terraform
          ] ++ (pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.k3s);

          shellHook = ''
            echo "🚀 nix-ks3-infra development shell activated"
            echo "Installed tools: kubectl, helm, k9s, opentofu, terraform${if pkgs.stdenv.hostPlatform.isLinux then ", k3s" else ""}"
            echo ""
            if [ -f /etc/rancher/k3s/k3s.yaml ] && [ -z "$KUBECONFIG" ]; then
              export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
              echo "💡 Auto-detected local KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
            fi
            alias k=kubectl
            alias tf=tofu
          '';
        };
      });
    };
}
