#################################################################################################################
# LOCALS
#################################################################################################################

locals {
  vnet_cidr           = ["10.10.0.0/24"]
  vm_subnet_cidr      = ["10.10.0.0/26"]
  fw_subnet_cidr      = ["10.10.0.64/26"]
  bastion_subnet_cidr = ["10.10.0.128/26"]
}

#################################################################################################################
# RESOURCE GROUP
#################################################################################################################

resource "azurerm_resource_group" "public" {
  location = var.location
  name     = "rg-azure-fw-${var.prefix}"
}

#################################################################################################################
# VNET AND SUBNET
#################################################################################################################

resource "azurerm_virtual_network" "public" {
  name                = "vnet-${var.prefix}"
  address_space       = local.vnet_cidr
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
}

resource "azurerm_subnet" "vm" {
  name                 = "snet-vm-${var.prefix}"
  resource_group_name  = azurerm_resource_group.public.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = local.vm_subnet_cidr
}

resource "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.public.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = local.fw_subnet_cidr
}

#################################################################################################################
# VIRTUAL MACHINES
#################################################################################################################

module "windows_vm" {
  source                      = "git::git@github.com:kolosovpetro/AzureWindowsVMTerraform.git//modules/windows-vm-custom-image-no-pip?ref=master"
  ip_configuration_name       = "ipc-vm1-${var.prefix}"
  network_interface_name      = "nic-vm1-${var.prefix}"
  network_security_group_id   = azurerm_network_security_group.public.id
  os_profile_admin_password   = trimspace(file("${path.root}/password.txt"))
  os_profile_admin_username   = "razumovsky_r"
  os_profile_computer_name    = "vm1-${var.prefix}"
  location                    = azurerm_resource_group.public.location
  resource_group_name         = azurerm_resource_group.public.name
  custom_image_resource_group = "rg-packer-images-win"
  custom_image_sku            = "windows-server2022-v1"
  storage_os_disk_name        = "osdisk-vm1-${var.prefix}"
  subnet_id                   = azurerm_subnet.vm.id
  vm_name                     = "vm1-${var.prefix}"
}

module "linux_vm" {
  source                    = "github.com/kolosovpetro/AzureLinuxVMTerraform.git//modules/ubuntu-vm-password-auth-custom-image-no-pip"
  ip_configuration_name     = "pip-vm2-${var.prefix}"
  network_interface_name    = "nic-vm2-${var.prefix}"
  os_profile_admin_password = trimspace(file("${path.root}/password.txt"))
  os_profile_admin_username = "razumovsky_r"
  os_profile_computer_name  = "vm2-${var.prefix}"
  resource_group_name       = azurerm_resource_group.public.name
  resource_group_location   = azurerm_resource_group.public.location
  storage_os_disk_name      = "osdisk-vm2-${var.prefix}"
  subnet_id                 = azurerm_subnet.vm.id
  vm_name                   = "vm2-${var.prefix}"
  network_security_group_id = azurerm_network_security_group.public.id
}

#################################################################################################################
# AZURE FIREWALL
#################################################################################################################

resource "azurerm_public_ip" "fw_pip" {
  name                = "fw-pip-${var.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.public.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw" {
  name                = "build-agent-fw-${var.prefix}"
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fw.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}

resource "azurerm_firewall_application_rule_collection" "devops_allow" {
  name                = "AllowAzureDevOps"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = azurerm_resource_group.public.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "AzureDevOps"

    source_addresses = local.vm_subnet_cidr

    target_fqdns = [
      "dev.azure.com",
      "aex.dev.azure.com",
      "mp.azure.net",
      "*.dev.azure.com",
      "*.visualstudio.com",
      "vsblobprodscus.blob.core.windows.net",
      "*.azureedge.net",
      "*.microsoftonline.com",
      "*.msauth.net",
      "*.dedup.microsoft.com",
      "*.vsassets.io",
    ]

    protocol {
      port = 443
      type = "Https"
    }
  }
}

#################################################################################################################
# ROUTE TABLE
#################################################################################################################

resource "azurerm_route_table" "agent_rt" {
  name                = "agent-rt-${var.prefix}"
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
}

resource "azurerm_route" "default_fw_route" {
  name                   = "default-to-fw"
  route_table_name       = azurerm_route_table.agent_rt.name
  resource_group_name    = azurerm_resource_group.public.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "agent_rt_assoc" {
  subnet_id      = azurerm_subnet.vm.id
  route_table_id = azurerm_route_table.agent_rt.id
}

#################################################################################################################
# BASTION
#################################################################################################################

resource "azurerm_subnet" "bastion_snet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.public.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = local.bastion_subnet_cidr
}

resource "azurerm_public_ip" "bastion_pip" {
  name                = "bastion-pip-${var.prefix}"
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "public" {
  name                = "bastion-${var.prefix}"
  copy_paste_enabled  = true
  file_copy_enabled   = true
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
  sku                 = "Standard"

  ip_configuration {
    name                 = "bastion-ipc-${var.prefix}"
    subnet_id            = azurerm_subnet.bastion_snet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}
