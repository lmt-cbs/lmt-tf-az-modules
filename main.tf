# Provider configuration
provider "azurerm" {
  features {}
}

# Resource Group
module "resource_group" {
  source  = "terraform-azurerm-modules/resource-group/azurerm"
  version = "2.0.0"

  location = "East US"
  name     = "example-resources"
}

# Virtual Network and Subnets
module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "3.0.0"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = ["10.0.0.0/16"]

  subnet_prefixes = {
    public  = "10.0.1.0/24"
    private = "10.0.2.0/24"
  }

  subnet_names = ["public", "private"]
}

# Network Security Group for the subnets
module "nsg" {
  source  = "terraform-azurerm-modules/network-security-group/azurerm"
  version = "3.0.0"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  security_rules = [
    {
      name                       = "AllowSSH"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "0.0.0.0/0"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowHTTP"
      priority                   = 1002
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "0.0.0.0/0"
      destination_address_prefix = "*"
    }
  ]
}

# Bastion Host
module "bastion_host" {
  source  = "Azure/bastion/azurerm"
  version = "2.0.0"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  vnet_name           = module.vnet.vnet["name"]
  subnet_id           = module.vnet.subnets[0]["id"] # Assuming public subnet is first

  name = "example-bastion"
}

# Ubuntu Virtual Machine
module "ubuntu_vm" {
  source  = "Azure/compute/azurerm"
  version = "4.0.0"

  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  vm_hostname   = "webserver"
  vm_size       = "Standard_DS1_v2"
  admin_username = "azureuser"

  admin_ssh_key = {
    username   = "azureuser"
    ssh_key    = file("~/.ssh/id_rsa.pub")
  }

  network_interface_ids = [module.vnet.subnets[1]["id"]] # Assuming private subnet is second

  os_disk = {
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  custom_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              echo "Hello World" > /var/www/html/index.html
              systemctl enable apache2
              systemctl start apache2
              EOF
}
