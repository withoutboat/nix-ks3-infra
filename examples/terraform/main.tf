terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13.0"
    }
  }
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to the K3s kubeconfig file"
  default     = "/etc/rancher/k3s/k3s.yaml"
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Example resource: Kubernetes namespace
resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
    labels = {
      managed-by = "terraform"
      env        = "production"
    }
  }
}

# Example resource: ConfigMap
resource "kubernetes_config_map" "app_settings" {
  metadata {
    name      = "app-settings"
    namespace = kubernetes_namespace.apps.metadata[0].name
  }

  data = {
    CLUSTER_NAME = "k3s-nix"
    ENVIRONMENT  = "production"
  }
}

output "namespace" {
  description = "Created Kubernetes namespace"
  value       = kubernetes_namespace.apps.metadata[0].name
}
