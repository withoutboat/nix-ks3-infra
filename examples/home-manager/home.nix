# Пример конфигурации пользователя Home Manager
{ config, pkgs, ... }:

{
  # Подключение модуля home-manager (если не через flake)
  # imports = [ ../../modules/home-manager ];

  programs.k3s-infra = {
    enable = true;

    # Установка CLI-утилит для работы с кластером
    tools = {
      enable = true;
      kubectl.enable = true;
      helm.enable = true;
      k9s.enable = true;
      opentofu.enable = true;
      terraform.enable = false; # Либо true при необходимости HashiCorp Terraform

      extraPackages = with pkgs; [
        kubectx
        stern
      ];
    };

    # Настройка kubeconfig пользователя
    kubeconfig = {
      enable = true;
      # Симлинк на системный kubeconfig, созданный K3s сервером
      symlinkSource = "/etc/rancher/k3s/k3s.yaml";
      setKubeconfigEnv = true;
    };

    # Полезные алиасы (k, kgp, kgpa, kga, kgs, klf, tf и др.)
    shellAliases = {
      enable = true;
      extraAliases = {
        kctx = "kubectx";
        kns = "kubens";
      };
    };
  };
}
