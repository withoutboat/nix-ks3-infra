# Конфигурация мастер-ноды (Server) для многоузлового кластера K3s
{ config, pkgs, ... }:

{
  services.k3s-infra = {
    enable = true;
    role = "server";

    # Инициализация встроенного etcd для высокой доступности (HA)
    clusterInit = true;

    # Токен для подключения других серверов и воркеров (рекомендуется передавать через tokenFile)
    tokenFile = "/run/secrets/k3s-node-token";
    # Либо для тестовых стендов:
    # token = "super-secret-cluster-token";

    # TLS SAN для доступа к API извне
    extraFlags = [
      "--tls-san 192.168.1.10"
      "--tls-san k8s.lan"
    ];

    firewall = {
      enable = true;
      openIngressPorts = true;
    };

    kubeconfig = {
      mode = "0644";
      setKubeconfigEnv = true;
    };
  };
}
