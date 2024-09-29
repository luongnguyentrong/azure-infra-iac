provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# Create a Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

# Create a Subnet
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

# NSG rule to allow intra-subnet communication
resource "azurerm_network_security_rule" "allow_intra_subnet" {
  name                        = "AllowIntraSubnet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "10.0.1.0/24"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = data.azurerm_resource_group.rg.name
}

# NSG rule to allow load balancer-vm communication
resource "azurerm_network_security_rule" "allow_load_balancer" {
  name                        = "AllowLoadBalancer"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "10.0.1.0/24"
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = data.azurerm_resource_group.rg.name
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create an Availability Set
resource "azurerm_availability_set" "avset" {
  name                = var.availability_set_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  managed             = true
  tags                = var.tags
}

# Create a Virtual Machine
resource "azurerm_network_interface" "vm_nic" {
  count               = var.vm_count
  name                = "${var.vm_name}-nic-${count.index}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal-vm-${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.tags
}

resource "azurerm_virtual_machine" "vm" {
  count                 = var.vm_count
  name                  = "${var.vm_name}-${count.index}"
  location              = var.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  availability_set_id   = azurerm_availability_set.avset.id
  network_interface_ids = [azurerm_network_interface.vm_nic[count.index].id]
  vm_size               = var.vm_size

  storage_os_disk {
    name              = "${var.vm_name}-osdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    id = data.azurerm_image.custom_vm_image.id
  }

  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = var.tags
}

# Data source to fetch the custom image
data "azurerm_image" "custom_vm_image" {
  name                = "udacity-vm-image"
  resource_group_name = var.resource_group_name
}

# Create a Public IP for the Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "lb-public-ip"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Create the Load Balancer
resource "azurerm_lb" "load_balancer" {
  name                = "udacity-lb"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }

  tags = var.tags
}

# Create Backend Address Pool for the Load Balancer
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name            = "backend-pool"
  loadbalancer_id = azurerm_lb.load_balancer.id
}

# Create Health Probe for HTTP traffic (port 80)
resource "azurerm_lb_probe" "http_probe" {
  name                = "http-probe"
  loadbalancer_id     = azurerm_lb.load_balancer.id
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
}

# Create Load Balancer Rule to forward HTTP traffic (port 80)
resource "azurerm_lb_rule" "http_lb_rule" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.load_balancer.id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "PublicIPAddress"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.http_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
}

# Associate Network Interface with Load Balancer's Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "nic_lb_association" {
  count = var.vm_count
  network_interface_id    = azurerm_network_interface.vm_nic[count.index].id
  ip_configuration_name   = azurerm_network_interface.vm_nic[count.index].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
}
