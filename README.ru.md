# nix-ks3-infra

Декларативная инфраструктура и Nix-модули для развертывания и управления легковесным Kubernetes-кластером (**K3s**) в NixOS и Home Manager.

---

## 🌟 Возможности

- **NixOS Module (`nixosModules.default`)**:
  - Минимальный запускаемый K3s сервер или агент в одну строчку конфигурации.
  - Поддержка одиночного узла (Single-Node) и высокодоступных отказоустойчивых кластеров (HA с embedded etcd).
  - Автоматическое управление правилами межсетевого экрана (NixOS Firewall) для API, kubelet, etcd и Flannel (VXLAN / WireGuard).
  - Возможность отключения встроенных компонентов K3s (`traefik`, `servicelb`, `local-storage`, `metrics-server`) для установки собственных решений (например, Cilium, Ingress-NGINX).
  - Настройка прав доступа к `kubeconfig` и автоматический экспорт переменной окружения `KUBECONFIG`.
  - Декларативное развертывание Kubernetes-манифестов прямо из Nix-конфигурации (`manifests`).
- **Home Manager Module (`homeManagerModules.default`)**:
  - **Минимальный запуск K3s в сессии пользователя**: запуск rootless K3s через `services.k3s-infra.enable = true` (или `programs.k3s-infra.server.enable = true`).
  - Пользовательский systemd-юнит `systemd.user.services.k3s-infra` с автостартом и утилитами управления `k3s-up` / `k3s-down`.
  - Подготовка рабочего окружения DevOps / администратора кластера (`kubectl`, `helm`, `k9s`, `opentofu`, `terraform`).
  - Симлинк или автоматическая генерация пользовательского `~/.kube/config` и экспорт `KUBECONFIG`.
  - Предустановленные шелловые алиасы (`k`, `kgp`, `kga`, `kgs`, `klf`, `tf` и др.).
- **DevShell (`nix develop`)**:
  - Готовая среда для администрирования кластера без необходимости загрязнять глобальную систему (`kubectl`, `helm`, `k9s`, `opentofu`, `terraform`, `k3s`).

---

## 📁 Структура репозитория

```text
nix-ks3-infra/
├── flake.nix                     # Flake с экспортом модулей и devShell
├── modules/
│   ├── nixos/
│   │   ├── default.nix           # Точка входа NixOS модуля и алиасы
│   │   └── k3s.nix               # Основная логика K3s службы, firewall и kubeconfig
│   └── home-manager/
│       ├── default.nix           # Точка входа Home Manager модуля
│       ├── service.nix           # Служба K3s rootless и утилиты k3s-up / k3s-down
│       └── tools.nix             # CLI-утилиты, kubeconfig и алиасы
├── examples/
│   ├── nixos/
│   │   └── configuration.nix     # Пример системного configuration.nix
│   ├── home-manager/
│   │   └── home.nix              # Пример конфигурации пользователя Home Manager
│   ├── multi-node/
│   │   ├── server.nix            # Мастер-нода кластера
│   │   └── agent.nix             # Воркер-нода (агент)
│   └── flake/
│       └── flake.nix             # Пример корневого flake с интеграцией системы и HM
└── README.md
```

---

## 🚀 Быстрый старт: DevShell

Для быстрого входа в окружение со всеми необходимыми утилитами:

```bash
nix develop
```

При входе в оболочку будут доступны:
- `kubectl` — клиент управления Kubernetes;
- `helm` — пакетный менеджер чартов Kubernetes;
- `k9s` — интерактивный консольный интерфейс (TUI) для мониторинга и управления;
- `opentofu` (`tofu`) и `terraform` — средства управления IaC;
- `k3s` (на Linux-хостах).

DevShell автоматически обнаруживает `/etc/rancher/k3s/k3s.yaml` и экспортирует `KUBECONFIG`, если он существует.

---

## 🛠️ Подключение модулей в Flake

Добавьте репозиторий в `inputs` вашего системного `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-ks3-infra.url = "github:withoutboat/nix-ks3-infra";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-ks3-infra, home-manager, ... }: {
    nixosConfigurations.my-k8s-node = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # 1. Подключение NixOS модуля K3s
        nix-ks3-infra.nixosModules.default

        ./configuration.nix
      ];
    };

    homeConfigurations."myuser" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      modules = [
        # 2. Подключение Home Manager модуля
        nix-ks3-infra.homeManagerModules.default

        ./home.nix
      ];
    };
  };
}
```

---

## ⚙️ Конфигурация NixOS модуля (`services.k3s-infra`)

### 1. Минимальный одиночный сервер (Single-Node K3s)

```nix
{
  services.k3s-infra = {
    enable = true;
    role = "server"; # По умолчанию
  };
}
```

Модуль автоматически:
1. Запустит сервис `k3s` в режиме control-plane + worker.
2. Откроет порт API сервера (`6443/tcp`) и Kubelet (`10250/tcp`).
3. Установит права `0644` на файл `/etc/rancher/k3s/k3s.yaml`.
4. Экспортирует переменную окружения `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` для всех сессий.
5. Установит `kubectl`, `helm` и `k9s` в систему.

### 2. Сервер с отключением стандартных компонентов и кастомными портами

```nix
{
  services.k3s-infra = {
    enable = true;
    role = "server";

    # Отключение компонентов для установки альтернатив (Cilium / Ingress NGINX / MetalLB)
    disabledComponents = [
      "traefik"
      "servicelb"
      "local-storage"
    ];

    # Открытие портов для входящего веб-трафика
    firewall = {
      enable = true;
      openIngressPorts = true; # 80 и 443 TCP
      additionalTCPPorts = [ 30000 30001 ]; # NodePort сервисы
    };

    # Автоматически применяемые манифесты при запуске K3s
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
```

### 3. Рабочий узел (Agent / Worker Node)

```nix
{
  services.k3s-infra = {
    enable = true;
    role = "agent";

    # Адрес мастер-ноды
    serverAddr = "https://192.168.1.10:6443";

    # Путь к файлу с токеном кластера (рекомендуется sops-nix или agenix)
    tokenFile = "/run/secrets/k3s-token";

    # Или строковый токен для тестовых сред:
    # token = "secret-token";
  };
}
```

### 4. Отказоустойчивый кластер (High-Availability c embedded etcd)

На первом сервере:
```nix
{
  services.k3s-infra = {
    enable = true;
    role = "server";
    clusterInit = true; # Инициализирует etcd
    tokenFile = "/run/secrets/k3s-token";
    extraFlags = [ "--tls-san k8s.example.com" ];
  };
}
```

На последующих серверах control-plane:
```nix
{
  services.k3s-infra = {
    enable = true;
    role = "server";
    serverAddr = "https://192.168.1.10:6443";
    tokenFile = "/run/secrets/k3s-token";
  };
}
```

---

## 📋 Таблица опций модуля NixOS

| Опция | Тип | По умолчанию | Описание |
|---|---|---|---|
| `services.k3s-infra.enable` | `bool` | `false` | Включение сервиса K3s. |
| `services.k3s-infra.role` | `enum [ "server" "agent" ]` | `"server"` | Роль ноды: `server` (мастер + воркер) или `agent` (только воркер). |
| `services.k3s-infra.serverAddr` | `nullOr str` | `null` | URL мастер-сервера (обязателен для `agent` и дополнительных мастеров). |
| `services.k3s-infra.token` | `nullOr str` | `null` | Токен кластера в виде строки. |
| `services.k3s-infra.tokenFile` | `nullOr path` | `null` | Путь к файлу с токеном кластера (рекомендуется). |
| `services.k3s-infra.clusterInit` | `bool` | `false` | Инициализировать HA кластер с embedded etcd. |
| `services.k3s-infra.port` | `port` | `6443` | Порт API-сервера K3s. |
| `services.k3s-infra.flannelBackend` | `enum [ "vxlan" "host-gw" "wireguard-native" "none" ]` | `"vxlan"` | Бэкенд Flannel CNI (`none` для Cilium/Calico). |
| `services.k3s-infra.disabledComponents` | `listOf str` | `[]` | Отключаемые компоненты (`traefik`, `servicelb`, `local-storage`, `metrics-server`). |
| `services.k3s-infra.extraFlags` | `listOf str` | `[]` | Произвольные аргументы командной строки K3s. |
| `services.k3s-infra.firewall.enable` | `bool` | `true` | Автоматически открывать порты в NixOS Firewall. |
| `services.k3s-infra.firewall.openIngressPorts` | `bool` | `false` | Открыть 80/tcp и 443/tcp для Ingress. |
| `services.k3s-infra.firewall.additionalTCPPorts` | `listOf port` | `[]` | Дополнительные TCP порты (например, NodePort). |
| `services.k3s-infra.firewall.additionalUDPPorts` | `listOf port` | `[]` | Дополнительные UDP порты. |
| `services.k3s-infra.kubeconfig.mode` | `nullOr str` | `"0644"` | Права доступа к `/etc/rancher/k3s/k3s.yaml`. |
| `services.k3s-infra.kubeconfig.setKubeconfigEnv`| `bool` | `true` | Экспортировать `KUBECONFIG` на уровне системы. |
| `services.k3s-infra.tools.enable` | `bool` | `true` | Устанавливать `kubectl`, `helm`, `k9s` в системные пакеты. |
| `services.k3s-infra.manifests` | `attrsOf (lines \| path)` | `{}` | Манифесты для автоприменения (`/var/lib/rancher/k3s/server/manifests/`). |

*Примечание: Также доступен совместимый псевдоним `services.ks3-infra`.*

---

## 👤 Конфигурация Home Manager

Модуль Home Manager поддерживает два взаимодополняющих сценария:
1. **Минимальный запуск K3s в домашней директории пользователя (`services.k3s-infra`)** в rootless-режиме;
2. **Настройка утилит разработчика, kubeconfig и алиасов (`programs.k3s-infra`)**.

### 1. Минимальный запуск K3s в Home Manager (`services.k3s-infra`)

```nix
{
  # Минимальный запуск K3s без root-прав (rootless)
  services.k3s-infra = {
    enable = true;
    # rootless = true; # По умолчанию
    # autoStart = true; # Автозапуск через systemd.user.services
  };

  # Утилиты управления
  programs.k3s-infra = {
    enable = true;
    tools.enable = true;
  };
}
```

При включении:
- Автоматически запускается K3s в rootless-режиме, сохраняя данные в `~/.local/share/k3s`.
- Записывается `~/.kube/config` и экспортируется `KUBECONFIG`.
- Доступны консольные помощники:
  - `k3s-up` — запуск пользовательского сервиса K3s;
  - `k3s-down` — остановка сервиса K3s.

*(Также доступен быстрый вариант активации через `programs.k3s-infra = { enable = true; server.enable = true; };`).*

### 2. Только клиентские инструменты (`programs.k3s-infra`)

```nix
{
  programs.k3s-infra = {
    enable = true;

    # Установка клиентских инструментов
    tools = {
      enable = true;
      kubectl.enable = true;
      helm.enable = true;
      k9s.enable = true;
      opentofu.enable = true;   # OpenTofu
      terraform.enable = false; # HashiCorp Terraform при необходимости
    };

    # Настройка kubeconfig пользователя (симлинк на системный K3s)
    kubeconfig = {
      enable = true;
      symlinkSource = "/etc/rancher/k3s/k3s.yaml";
      setKubeconfigEnv = true;
    };

    # Предустановленные полезные алиасы
    shellAliases = {
      enable = true;
      extraAliases = {
        kctx = "kubectx";
      };
    };
  };
}
```

### Таблица опций Home Manager

#### Пользовательский сервис (`services.k3s-infra`)

| Опция | Тип | По умолчанию | Описание |
|---|---|---|---|
| `services.k3s-infra.enable` | `bool` | `false` | Включение сервиса K3s в сессии пользователя. |
| `services.k3s-infra.role` | `enum [ "server" "agent" ]` | `"server"` | Роль ноды (`server` или `agent`). |
| `services.k3s-infra.rootless` | `bool` | `true` | Запуск в режиме rootless. |
| `services.k3s-infra.dataDir` | `str` | `"~/.local/share/k3s"` | Каталог состояния K3s. |
| `services.k3s-infra.port` | `port` | `6443` | Порт API сервера. |
| `services.k3s-infra.serverAddr` | `nullOr str` | `null` | Адрес сервера для подключения (для агента). |
| `services.k3s-infra.token` | `nullOr str` | `null` | Токен кластера. |
| `services.k3s-infra.disabledComponents` | `listOf str` | `[]` | Отключаемые компоненты (`traefik`, `servicelb` и др.). |
| `services.k3s-infra.autoStart` | `bool` | `true` | Автозапуск через systemd user service. |
| `services.k3s-infra.kubeconfig.path` | `str` | `"~/.kube/config"` | Путь для записи kubeconfig. |
| `services.k3s-infra.kubeconfig.setKubeconfigEnv` | `bool` | `true` | Экспорт переменной `KUBECONFIG`. |
| `services.k3s-infra.helperScripts` | `bool` | `true` | Установка скриптов `k3s-up` и `k3s-down`. |

*Примечание: Также доступен совместимый псевдоним `services.ks3-infra`.*

#### Инструменты пользователя (`programs.k3s-infra`)

| Опция | Тип | По умолчанию | Описание |
|---|---|---|---|
| `programs.k3s-infra.enable` | `bool` | `false` | Включение модуля пользовательского окружения. |
| `programs.k3s-infra.server.enable` | `bool` | `false` | Ярлык для включения `services.k3s-infra.enable`. |
| `programs.k3s-infra.tools.enable` | `bool` | `true` | Установка инструментов управления (`kubectl`, `helm`, `k9s`, `opentofu`). |
| `programs.k3s-infra.tools.kubectl.enable` | `bool` | `true` | Установка `kubectl`. |
| `programs.k3s-infra.tools.helm.enable` | `bool` | `true` | Установка `kubernetes-helm`. |
| `programs.k3s-infra.tools.k9s.enable` | `bool` | `true` | Установка `k9s`. |
| `programs.k3s-infra.tools.opentofu.enable` | `bool` | `true` | Установка `opentofu`. |
| `programs.k3s-infra.tools.terraform.enable` | `bool` | `false` | Установка `terraform`. |
| `programs.k3s-infra.tools.extraPackages` | `listOf package` | `[]` | Дополнительные пакеты для установки. |
| `programs.k3s-infra.kubeconfig.enable` | `bool` | `true` | Управление файлом kubeconfig. |
| `programs.k3s-infra.kubeconfig.path` | `str` | `".kube/config"` | Относительный путь к kubeconfig в домашней директории. |
| `programs.k3s-infra.kubeconfig.symlinkSource` | `nullOr str` | `null` | Системный путь для создания симлинка (например, `/etc/rancher/k3s/k3s.yaml`). |
| `programs.k3s-infra.kubeconfig.source` | `nullOr path` | `null` | Nix store путь для kubeconfig. |
| `programs.k3s-infra.kubeconfig.content` | `nullOr lines` | `null` | Содержимое kubeconfig в виде строки. |
| `programs.k3s-infra.kubeconfig.setKubeconfigEnv` | `bool` | `false` | Экспорт переменной `KUBECONFIG`. |
| `programs.k3s-infra.shellAliases.enable` | `bool` | `true` | Включение удобных алиасов для `kubectl` и `tofu`. |
| `programs.k3s-infra.shellAliases.extraAliases` | `attrsOf str` | `{}` | Пользовательские дополнительные алиасы. |

*Примечание: Также доступен совместимый псевдоним `programs.ks3-infra`.*

### Полезные встроенные алиасы:
- `k` ➔ `kubectl`
- `kgp` ➔ `kubectl get pods`
- `kgpa` ➔ `kubectl get pods -A`
- `kga` ➔ `kubectl get all`
- `kgn` ➔ `kubectl get nodes`
- `kgs` ➔ `kubectl get svc`
- `kgi` ➔ `kubectl get ingress`
- `kd` ➔ `kubectl describe`
- `kdp` ➔ `kubectl describe pod`
- `kl` ➔ `kubectl logs`
- `klf` ➔ `kubectl logs -f`
- `kex` ➔ `kubectl exec -it`
- `kdel` ➔ `kubectl delete`
- `kapply` ➔ `kubectl apply -f`
- `tf` ➔ `tofu`

---

## 🔒 Безопасность и хранение секретов

Для передачи кластерного токена настоятельно рекомендуется избегать открытого текста в git-репозитории:
- Используйте инструмент **[sops-nix](https://github.com/Mic92/sops-nix)** или **[agenix](https://github.com/ryantm/agenix)**.
- Укажите путь к расшифрованному файлу:
  ```nix
  services.k3s-infra.tokenFile = config.sops.secrets."k3s-token".path;
  ```

---

## 📄 Лицензия

MIT
