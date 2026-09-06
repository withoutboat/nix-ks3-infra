# Пример конфигурации пользователя Home Manager
{ config, pkgs, ... }:

{
  # Подключение модуля home-manager (если не через flake)
  # imports = [ ../../modules/home-manager ];

  # 1. Минимальный запуск K3s в домашнем каталоге пользователя (rootless)
  services.k3s-infra = {
    enable = true;          # Включение пользовательского сервиса K3s
    rootless = true;        # Запуск без root прав
    autoStart = true;       # Автостарт через systemd user service (на Linux)
    # port = 6443;
    # disabledComponents = [ "traefik" "servicelb" ]; # опционально
  };

  # 2. Утилиты разработчика и окружение
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

    # Настройка kubeconfig пользователя (по умолчанию использует ~/.kube/config от локального сервиса K3s)
    kubeconfig = {
      enable = true;
      setKubeconfigEnv = true;
      # Для подключения к системному K3s вместо локального:
      # symlinkSource = "/etc/rancher/k3s/k3s.yaml";
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
