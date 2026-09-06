# Конфигурация рабочего узла (Agent / Worker) K3s
{ config, pkgs, ... }:

{
  services.k3s-infra = {
    enable = true;
    role = "agent";

    # Адрес мастер-сервера для подключения
    serverAddr = "https://192.168.1.10:6443";

    # Общий токен кластера (тот же, что и на сервере)
    tokenFile = "/run/secrets/k3s-node-token";
    # Либо для тестов:
    # token = "super-secret-cluster-token";

    # Автоматическое открытие портов Kubelet (10250) и Flannel VXLAN (8472)
    firewall = {
      enable = true;
      openIngressPorts = true; # Если на ноду направлен балансировщик трафика
    };

    # Для agent kubeconfig на сервере не генерируется
    kubeconfig.setKubeconfigEnv = false;
  };
}
