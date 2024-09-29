packer {
  required_plugins {
    azure = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "subscription_id" {
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "resource_group" {
  type    = string
  default = "Azuredevops"
}

variable "vm_size" {
  type    = string
  default = "Standard_DS1_v2"
}

source "azure-arm" "udacity" {
  managed_image_resource_group_name = var.resource_group
  build_resource_group_name         = var.resource_group
  managed_image_name                = "udacity-vm-image"
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  subscription_id                   = var.subscription_id

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "UbuntuServer"
  image_sku       = "18.04-LTS"
  vm_size         = var.vm_size

  azure_tags = {
    project = "udacity",
  }
}

build {
  sources = ["source.azure-arm.udacity"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
      "echo 'Hello, World!' | sudo tee /var/www/html/index.html",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx"
    ]
    inline_shebang = "/bin/sh -x"
  }
}
