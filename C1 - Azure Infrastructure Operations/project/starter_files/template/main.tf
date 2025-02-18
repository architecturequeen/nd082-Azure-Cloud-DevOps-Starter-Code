# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet in virtual network
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.2.0/24"
}


# security group to deny all inbound traffic (includes internet as a result)
resource "azurerm_network_security_group" "nsg1" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "DenyAllInboundTraffic"
    priority                   = 500
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}


# security group to allow outbound traffic within subnet 
resource "azurerm_network_security_group" "nsg2" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allowOutboundSubnetTraffic"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "10.0.2.0/24"
  }
}

# security group to allow inbound traffic within subnet 
resource "azurerm_network_security_group" "nsg3" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allowInboundSubnetTraffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "10.0.2.0/24"
  }
}

# create network interface
resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# create public ip
resource "azurerm_public_ip" "publicip" {
  name                = "${var.prefix}-pubip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"

  tags = {
    environment = ""
  }
}

# create load balancer
resource "azurerm_lb" "lb" {
  name                = "${var.prefix}-lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.publicip.id
  }
}

# create backend address pool
resource "azurerm_lb_backend_address_pool" "backendpool" {
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "${var.prefix}-bakendpool"
}

# create association between a Network Interface and load balancer backend pool
resource "azurerm_network_interface_backend_address_pool_association" "nicbp" {
  network_interface_id    = azurerm_network_interface.nic.id
  ip_configuration_name   = "configuration1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
}

# create virtual machine availability set
resource "azurerm_availability_set" "avset" {
  name                = "${var.prefix}-avset"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = ""
  }
}
