variable "subscription_id" {
  description = "The name of the subscription id."
  type        = string
}
variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
  default     = "Azuredevops"
}

variable "location" {
  description = "The Azure region to deploy the resources in."
  type        = string
  default     = "West Europe"
}

variable "vnet_name" {
  description = "The name of the Virtual Network."
  type        = string
  default     = "udacity-vnet"
}

variable "subnet_name" {
  description = "The name of the Subnet."
  type        = string
  default     = "udacity-subnet"
}

variable "nsg_name" {
  description = "The name of the Network Security Group."
  type        = string
  default     = "udacity-nsg"
}

variable "availability_set_name" {
  description = "The name of the Availability Set."
  type        = string
  default     = "udacity-avset"
}

variable "vm_name" {
  description = "The name of the Virtual Machine."
  type        = string
  default     = "udacity-vm"
}

variable "vm_count" {
  description = "Number of Virtual Machines to deploy"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "The size of the Virtual Machine."
  type        = string
  default     = "Standard_DS1_v2"
}

variable "admin_username" {
  description = "The admin username for the Virtual Machine."
  type        = string
  default     = "adminuser"
}

variable "admin_password" {
  description = "The admin password for the Virtual Machine."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default = {
    environment = "development"
    project     = "udacity"
  }
}
