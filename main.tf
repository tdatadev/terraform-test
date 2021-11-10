terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "testformgroup" {
    name     = "myResourceGroup"
    location = "eastus"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_network" "testformnetwork" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.testformgroup.name

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_subnet" "testformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.testformgroup.name
    virtual_network_name = azurerm_virtual_network.testformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "testformpublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.testformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_security_group" "testformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = "northeurope"
    resource_group_name = azurerm_resource_group.testformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface" "testformnic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.testformgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.testformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.testformpublicip.id
    }

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.testformnic.id
    network_security_group_id = azurerm_network_security_group.testformnsg.id
}

resource "random_id" "randomId" {
    keepers = {
        resource_group = azurerm_resource_group.testformgroup.name
    }

    byte_length = 8
}

resource "azurerm_storage_account" "mystorgeaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.testformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.example_ssh.private_key_pem 
    sensitive = true
}

resource "azurerm_linux_virtual_machine" "testformvm" {
    location              = "northeurope"
    resource_group_name   = azurerm_resource_group.testformgroup.name
    network_interface_ids = [azurerm_network_interface.testformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "testvm"
    admin_username = "testuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "testuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}