# Пример корневого flake.nix, использующего модули nix-ks3-infra
{
  description = "Example infrastructure flake using nix-ks3-infra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Подключение нашего flake с K3s инфраструктурой
    nix-ks3-infra.url = "github:withoutboat/nix-ks3-infra";
    # Или локальный путь при разработке:
    # nix-ks3-infra.url = "path:../..";
  };

  outputs = { self, nixpkgs, home-manager, nix-ks3-infra, ... }:
    let
      system = "x86_64-linux";
    in
    {
      # Конфигурация NixOS сервера
      nixosConfigurations.k3s-master = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Подключение NixOS модуля K3s
          nix-ks3-infra.nixosModules.default

          ({ pkgs, ... }: {
            networking.hostName = "k3s-master";

            services.k3s-infra = {
              enable = true;
              role = "server";
              firewall.enable = true;
              firewall.openIngressPorts = true;
              kubeconfig.mode = "0644";
            };
          })
        ];
      };

      # Конфигурация Home Manager
      homeConfigurations."devops" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [
          # Подключение Home Manager модуля с инструментами
          nix-ks3-infra.homeManagerModules.default

          ({ pkgs, ... }: {
            home.username = "devops";
            home.homeDirectory = "/home/devops";
            home.stateVersion = "24.05";

            programs.k3s-infra = {
              enable = true;
              tools.enable = true; # kubectl, helm, k9s, opentofu
              kubeconfig = {
                enable = true;
                symlinkSource = "/etc/rancher/k3s/k3s.yaml";
                setKubeconfigEnv = true;
              };
            };
          })
        ];
      };
    };
}
