terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Uncomment to use Azure Blob as remote state backend
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstateXXXXXX"
  #   container_name       = "tfstate"
  #   key                  = "aksazuregitopslab.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

# ── Variables ────────────────────────────────────────────────────────────────
variable "location"       { default = "eastus" }
variable "resource_group" { default = "aksazuregitopslab-rg" }
variable "cluster_name"   { default = "aksazuregitopslab-cluster" }
variable "acr_name"       { default = "aksdemoregistry" }   # must be globally unique
variable "node_count"     { default = 2 }
variable "vm_size"        { default = "Standard_D2s_v3" }

# ── Resource Group ───────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = var.resource_group
  location = var.location
}

# ── Azure Container Registry ─────────────────────────────────────────────────
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false
}

# ── AKS Cluster ──────────────────────────────────────────────────────────────
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.cluster_name

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = var.vm_size

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = {
    environment = "demo"
  }
}

# ── Grant AKS pull access to ACR ─────────────────────────────────────────────
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# ── Outputs ──────────────────────────────────────────────────────────────────
output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "resource_group" {
  value = azurerm_resource_group.main.name
}
