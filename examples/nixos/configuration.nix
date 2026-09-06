# Пример системной конфигурации NixOS с использованием модуля k3s-infra
{ config, pkgs, ... }:

{
  # Подключение модуля k3s-infra (если подключается напрямую, а не через flake inputs)
  # imports = [ ../../modules/nixos ];

  # Настройка K3s сервера
  services.k3s-infra = {
    enable = true;
    role = "server";

    # Порт API сервера (по умолчанию 6443)
    port = 6443;

    # Автоматическое открытие необходимых портов в firewall (6443, 10250, Flannel VXLAN 8472)
    firewall = {
      enable = true;
      openIngressPorts = true; # Открыть 80 и 443 для HTTP/HTTPS
      additionalTCPPorts = [ 30000 ]; # Например, для NodePort
    };

    # Отключение компонентов, если планируется внешняя замена (например, Cilium, Ingress NGINX)
    # disabledComponents = [ "traefik" "servicelb" ];

    # Права на файл kubeconfig для чтения непривилегированным пользователем
    kubeconfig = {
      mode = "0644"; # Позволяет пользователям читать /etc/rancher/k3s/k3s.yaml
      setKubeconfigEnv = true; # Экспортирует системную переменную KUBECONFIG
    };

    # Установка CLI-утилит (kubectl, helm, k9s) в систему
    tools = {
      enable = true;
      extraPackages = with pkgs; [
        cilium-cli
      ];
    };

    # Дополнительные флаги запуска
    extraFlags = [
      "--tls-san 127.0.0.1"
      "--tls-san 192.168.1.100"
    ];

    # Декларативные манифесты, разворачиваемые автоматически при старте
    manifests = {
      "demo-namespace.yaml" = ''
        apiVersion: v1
        kind: Namespace
        metadata:
          name: demo
      '';
    };
  };
}
