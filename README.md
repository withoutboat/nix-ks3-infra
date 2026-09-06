# nix-ks3-infra

Declarative Nix infrastructure and modules for deploying and managing lightweight Kubernetes (**K3s**) clusters on NixOS, accompanied by Home Manager developer tooling and **Terraform / OpenTofu** IaC integration.

---

## 🌟 Key Features

- **NixOS System Module (`nixosModules.default`)**:
  - One-line setup for a production-ready K3s control-plane or worker node.
  - Supports both standalone Single-Node setups and High-Availability (HA) multi-master clusters with embedded etcd (`clusterInit = true`).
  - Automated NixOS Firewall configuration for API server, Kubelet, etcd, and Flannel CNI (VXLAN / WireGuard).
  - Ability to disable built-in K3s components (`traefik`, `servicelb`, `local-storage`, `metrics-server`) to deploy custom alternatives (such as Cilium or Ingress-NGINX).
  - Flexible `kubeconfig` permissions (`mode = "0644"`) and automatic system-wide `KUBECONFIG` environment variable export.
  - Native declarative Kubernetes manifests deployment directly from Nix configurations (`manifests`).
  - System-level installation of DevOps & IaC tools (`kubectl`, `helm`, `k9s`, `opentofu`, `terraform`).

- **Home Manager Module (`homeManagerModules.default`)**:
  - Sets up complete Kubernetes and DevOps developer workstation tooling.
  - Manages `kubectl`, `helm`, `k9s`, `opentofu`, and `terraform`.
  - Automatic `~/.kube/config` symlinking (e.g., to `/etc/rancher/k3s/k3s.yaml` via `mkOutOfStoreSymlink`) and session variable exports.
  - Pre-configured shell aliases (`k`, `kgp`, `kgpa`, `kga`, `kgn`, `kgs`, `klf`, `tf`, etc.).

- **Terraform & OpenTofu Support**:
  - Available out of the box in `devShell` (`nix develop`).
  - Configurable in both NixOS and Home Manager modules (`tools.opentofu.enable` and `tools.terraform.enable`).
  - Includes working Terraform/OpenTofu examples (`examples/terraform/`) configuring Kubernetes and Helm providers against the local K3s cluster.

- **DevShell (`nix develop`)**:
  - Ready-to-use operator shell containing `kubectl`, `helm`, `k9s`, `opentofu`, `terraform`, and `k3s` (on Linux hosts).
  - Automatic detection of `/etc/rancher/k3s/k3s.yaml` with zero-config setup.

---

## 📁 Repository Structure

```text
nix-ks3-infra/
├── flake.nix                     # Flake exporting modules and devShell
├── modules/
│   ├── nixos/
│   │   ├── default.nix           # NixOS module entry point and aliases
│   │   └── k3s.nix               # K3s service, firewall, and kubeconfig logic
│   └── home-manager/
│       ├── default.nix           # Home Manager module entry point
│       └── tools.nix             # CLI utilities, kubeconfig, and shell aliases
├── examples/
│   ├── nixos/
│   │   └── configuration.nix     # Example NixOS configuration
│   ├── home-manager/
│   │   └── home.nix              # Example Home Manager user configuration
│   ├── multi-node/
│   │   ├── server.nix            # Multi-node primary server (HA etcd)
│   │   └── agent.nix             # Multi-node worker agent
│   ├── flake/
│   │   └── flake.nix             # Root flake integration example
│   └── terraform/
│       └── main.tf               # Terraform/OpenTofu example with K8s/Helm providers
├── README.ru.md                  # Russian documentation
└── README.md                     # Main English documentation
```

---

## 🚀 Quickstart: DevShell

To enter a development and administration shell with all tools pre-installed:

```bash
nix develop
```

The shell provides:
- `kubectl` — Kubernetes CLI;
- `helm` — Kubernetes package manager;
- `k9s` — Terminal UI for Kubernetes;
- `opentofu` (`tofu`) — Open-source Terraform fork;
- `terraform` — HashiCorp Terraform CLI;
- `k3s` — K3s binary (on Linux platforms).

When launched, the devShell automatically checks for `/etc/rancher/k3s/k3s.yaml` and exports `KUBECONFIG` if present.

---

## 🏗️ Terraform & OpenTofu Support

Terraform and OpenTofu are supported across the stack:

1. **In DevShell**: Run `tofu` or `terraform` immediately after entering `nix develop`.
2. **In NixOS Module**: Enable `services.k3s-infra.tools.opentofu.enable = true` or `tools.terraform.enable = true`.
3. **In Home Manager**: Enable `programs.k3s-infra.tools.opentofu.enable = true` or `tools.terraform.enable = true` (also configures the `tf` alias).
4. **Sample Terraform Project**: See `examples/terraform/main.tf` for an example of configuring Kubernetes and Helm providers pointing to `/etc/rancher/k3s/k3s.yaml`:

```bash
cd examples/terraform
tofu init
tofu plan
tofu apply
```

*(Note: HashiCorp Terraform requires `nixpkgs.config.allowUnfree = true` in Nix due to its BSL license. OpenTofu is fully open-source and enabled by default).*

---

## 🛠️ Flake Integration

Add `nix-ks3-infra` to your system `flake.nix`:

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
        # NixOS K3s module
        nix-ks3-infra.nixosModules.default

        ./configuration.nix
      ];
    };

    homeConfigurations."myuser" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      modules = [
        # Home Manager tools module
        nix-ks3-infra.homeManagerModules.default

        ./home.nix
      ];
    };
  };
}
```

---

## ⚙️ NixOS Module Configuration (`services.k3s-infra`)

### 1. Minimal Standalone Server (Single-Node K3s)

```nix
{
  services.k3s-infra = {
    enable = true;
    role = "server"; # Default
  };
}
```

This minimal configuration automatically:
1. Runs `k3s` in server mode (control-plane + worker).
2. Opens firewall ports for API Server (`6443/tcp`) and Kubelet (`10250/tcp`).
3. Sets `/etc/rancher/k3s/k3s.yaml` permissions to `0644`.
4. Exports `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` system-wide.
5. Installs `kubectl`, `helm`, and `k9s`.

### 2. Server with Custom Networking and Disabled Components

```nix
{
  services.k3s-infra = {
    enable = true;
    role = "server";

    # Disable built-in components to install custom ones (e.g. Cilium, Ingress-NGINX)
    disabledComponents = [
      "traefik"
      "servicelb"
      "local-storage"
    ];

    # Open firewall ports for web traffic and NodePort
    firewall = {
      enable = true;
      openIngressPorts = true; # TCP 80 & 443
      additionalTCPPorts = [ 30000 30001 ];
    };

    # Automatically applied manifests
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

### 3. Worker Node (Agent)

```nix
{
  services.k3s-infra = {
    enable = true;
    role = "agent";

    # Master server address
    serverAddr = "https://192.168.1.10:6443";

    # Path to cluster token file
    tokenFile = "/run/secrets/k3s-token";
  };
}
```

### 4. High-Availability Cluster (HA with embedded etcd)

Primary server:
```nix
{
  services.k3s-infra = {
    enable = true;
    role = "server";
    clusterInit = true; # Initializes embedded etcd
    tokenFile = "/run/secrets/k3s-token";
    extraFlags = [ "--tls-san k8s.example.com" ];
  };
}
```

Secondary control-plane servers:
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

## 📋 NixOS Module Options Reference

| Option | Type | Default | Description |
|---|---|---|---|
| `services.k3s-infra.enable` | `bool` | `false` | Enable K3s infrastructure service. |
| `services.k3s-infra.role` | `enum [ "server" "agent" ]` | `"server"` | Node role (`server` or `agent`). |
| `services.k3s-infra.serverAddr` | `nullOr str` | `null` | URL of the control-plane server to join. |
| `services.k3s-infra.token` | `nullOr str` | `null` | Cluster join token (string). |
| `services.k3s-infra.tokenFile` | `nullOr path` | `null` | Path to cluster join token file (recommended). |
| `services.k3s-infra.clusterInit` | `bool` | `false` | Initialize HA cluster with embedded etcd. |
| `services.k3s-infra.port` | `port` | `6443` | API server listen port. |
| `services.k3s-infra.flannelBackend` | `enum [ "vxlan" "host-gw" "wireguard-native" "none" ]` | `"vxlan"` | Flannel CNI backend (`none` for Cilium/Calico). |
| `services.k3s-infra.disabledComponents` | `listOf str` | `[]` | Components to disable (`traefik`, `servicelb`, `local-storage`, `metrics-server`). |
| `services.k3s-infra.extraFlags` | `listOf str` | `[]` | Extra CLI flags passed to K3s. |
| `services.k3s-infra.firewall.enable` | `bool` | `true` | Automatically configure NixOS firewall rules. |
| `services.k3s-infra.firewall.openIngressPorts` | `bool` | `false` | Open 80/tcp and 443/tcp for Ingress. |
| `services.k3s-infra.firewall.additionalTCPPorts` | `listOf port` | `[]` | Additional TCP ports to allow. |
| `services.k3s-infra.firewall.additionalUDPPorts` | `listOf port` | `[]` | Additional UDP ports to allow. |
| `services.k3s-infra.kubeconfig.mode` | `nullOr str` | `"0644"` | Permissions for `/etc/rancher/k3s/k3s.yaml`. |
| `services.k3s-infra.kubeconfig.setKubeconfigEnv`| `bool` | `true` | Export `KUBECONFIG` system-wide. |
| `services.k3s-infra.tools.enable` | `bool` | `true` | Install DevOps & IaC tools in system packages. |
| `services.k3s-infra.tools.opentofu.enable` | `bool` | `true` | Install OpenTofu system-wide. |
| `services.k3s-infra.tools.terraform.enable` | `bool` | `false` | Install Terraform system-wide (unfree). |
| `services.k3s-infra.manifests` | `attrsOf (lines | path)` | `{}` | Declarative manifests for `/var/lib/rancher/k3s/server/manifests/`. |

*Note: Compatible option alias `services.ks3-infra` is also available.*

---

## 👤 Home Manager Configuration (`programs.k3s-infra`)

```nix
{
  programs.k3s-infra = {
    enable = true;

    # CLI tools configuration
    tools = {
      enable = true;
      kubectl.enable = true;
      helm.enable = true;
      k9s.enable = true;
      opentofu.enable = true;   # OpenTofu CLI
      terraform.enable = false; # Terraform CLI (requires allowUnfree)
    };

    # Kubeconfig configuration
    kubeconfig = {
      enable = true;
      symlinkSource = "/etc/rancher/k3s/k3s.yaml";
      setKubeconfigEnv = true;
    };

    # Shell aliases
    shellAliases = {
      enable = true;
      extraAliases = {
        kctx = "kubectx";
      };
    };
  };
}
```

### Home Manager Options Reference

| Option | Type | Default | Description |
|---|---|---|---|
| `programs.k3s-infra.enable` | `bool` | `false` | Enable user environment tooling. |
| `programs.k3s-infra.tools.enable` | `bool` | `true` | Install cluster & IaC tools (`kubectl`, `helm`, `k9s`, `opentofu`). |
| `programs.k3s-infra.tools.kubectl.enable` | `bool` | `true` | Install `kubectl`. |
| `programs.k3s-infra.tools.helm.enable` | `bool` | `true` | Install `helm`. |
| `programs.k3s-infra.tools.k9s.enable` | `bool` | `true` | Install `k9s`. |
| `programs.k3s-infra.tools.opentofu.enable` | `bool` | `true` | Install `opentofu`. |
| `programs.k3s-infra.tools.terraform.enable` | `bool` | `false` | Install `terraform`. |
| `programs.k3s-infra.tools.extraPackages` | `listOf package` | `[]` | Additional user packages. |
| `programs.k3s-infra.kubeconfig.enable` | `bool` | `true` | Manage user kubeconfig. |
| `programs.k3s-infra.kubeconfig.path` | `str` | `".kube/config"` | Relative path to kubeconfig in home directory. |
| `programs.k3s-infra.kubeconfig.symlinkSource` | `nullOr str` | `null` | System path to symlink (e.g. `/etc/rancher/k3s/k3s.yaml`). |
| `programs.k3s-infra.kubeconfig.source` | `nullOr path` | `null` | Nix store path for kubeconfig. |
| `programs.k3s-infra.kubeconfig.content` | `nullOr lines` | `null` | Kubeconfig string content. |
| `programs.k3s-infra.kubeconfig.setKubeconfigEnv` | `bool` | `false` | Export `KUBECONFIG` environment variable. |
| `programs.k3s-infra.shellAliases.enable` | `bool` | `true` | Enable convenient shell aliases for `kubectl` and `tofu`/`terraform`. |

*Note: Compatible option alias `programs.ks3-infra` is also available.*

### Included Shell Aliases:
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
- `tf` ➔ `tofu` (or `terraform` if only terraform is enabled)

---

## 🔒 Security & Secrets Management

To avoid committing sensitive cluster tokens to Git:
- Use **[sops-nix](https://github.com/Mic92/sops-nix)** or **[agenix](https://github.com/ryantm/agenix)**.
- Pass the decrypted file path to `tokenFile`:
  ```nix
  services.k3s-infra.tokenFile = config.sops.secrets."k3s-token".path;
  ```

---

## 📄 License

MIT
