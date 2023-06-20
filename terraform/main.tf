#create resource group
resource "azurerm_resource_group" "media-wiki" {
  name     = "  "
  location = "eastus"
}

# creat Network Security Groups
resource "azurerm_network_security_group" "media-wiki" {
  name                = "media-wiki-nsg"
  
  location            = azurerm_resource_group.media-wiki.location
  resource_group_name = azurerm_resource_group.media-wiki.name
}
# create Vnet
resource "azurerm_virtual_network" "media-wiki" {
  name                = "media-wiki-network"
  location            = azurerm_resource_group.media-wiki.location
  resource_group_name = azurerm_resource_group.media-wiki.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Dev"
  }
}
resource "azurerm_subnet" "subnet" {
  name                 = "media_wiki_subnet"
  resource_group_name  = azurerm_resource_group.media-wiki.name
  address_prefix       = "10.0.1.0/24"
  virtual_network_name = azurerm_virtual_network.media-wiki.name
}

#Keyvault Creation
data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "kv1" {
  depends_on = [ azurerm_resource_group.media-wiki ]
  name                        = "media-wiki-kv"
  location                    = azurerm_resource_group.media-wiki.location
  resource_group_name         = azurerm_resource_group.media-wiki.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name = "standard"
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "get",
    ]
    secret_permissions = [
      "get", "backup", "delete", "list", "purge", "recover", "restore", "set",
    ]
    storage_permissions = [
      "get",
    ]
  }
}

#Create Random passwords
resource "random_password" "rand1" {
  length = 10
  special = true
}

resource "random_password" "rand2" {
  length = 10
  special = true
}
#Create Key Vault Secrets
resource "azurerm_key_vault_secret" "rand1" {
  name         = "sqlrootpassword"
  value        = random_password.rand1.result
  key_vault_id = azurerm_key_vault.kv1.id
  depends_on = [ azurerm_key_vault.kv1 ]
}

resource "azurerm_key_vault_secret" "rand2" {
  name         = "sqluserpassword"
  value        = random_password.rand2.result
  key_vault_id = azurerm_key_vault.kv1.id
  depends_on = [ azurerm_key_vault.kv1 ]
}

# service_principle.client-id
data "azurerm_key_vault_secret" "client-id" {
  name         = "clientid"
  key_vault_id = azurerm_key_vault.kv1.id
}
# service_principle.client-secret
data "azurerm_key_vault_secret" "client-secret" {
  name         = "clientsecret"
  key_vault_id = azurerm_key_vault.kv1.id
}

# create log analytic worspace
resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "lgw" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "media-wiki-lg-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = azurerm_resource_group.media-wiki.location
    resource_group_name = azurerm_resource_group.media-wiki.name
    sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "lgw" {
    solution_name         = "ContainerInsights"
    location              = azurerm_resource_group.media-wiki.location
    resource_group_name   = azurerm_resource_group.media-wiki.name
    workspace_resource_id = azurerm_log_analytics_workspace.lgw.id
    workspace_name        = azurerm_log_analytics_workspace.lgw.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

# creating kubernetes cluster 


resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.media-wiki.location
  resource_group_name = azurerm_resource_group.media-wiki.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.k8_version
  
  default_node_pool {
    name       = "default"
    vnet_subnet_id = azurerm_subnet.subnet.id
    vm_size    = var.vm_size
    enable_auto_scaling = false
    node_count = 1
    max_pods = 30

    //autoscaling
    #min_count           = "1"
    #max_count           = "10"
  }


  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
    service_cidr       = var.service_cidr
  }

  service_principal {
    client_id     = data.azurerm_key_vault_secret.client-id.value
    client_secret = data.azurerm_key_vault_secret.client-secret.value
  }
    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = azurerm_log_analytics_workspace.lgw.id
        }
    }
  tags = {
    Environment = "Test"
  }
    depends_on = [ azurerm_subnet.subnet ]
}
