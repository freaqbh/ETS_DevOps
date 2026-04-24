variable "location" {
  description = "Region Azure tempat semua resource akan di-deploy"
  type        = string
  default     = "Malaysia West"
}

variable "resource_group_name" {
  description = "Nama Resource Group utama"
  type        = string
  default     = "rg-devops-miniproject"
}

variable "vnet_name" {
  description = "Nama Virtual Network"
  type        = string
  default     = "vnet-ubuntu-lab"
}

variable "vnet_address_space" {
  description = "CIDR block untuk Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  description = "Nama Subnet di dalam VNet"
  type        = string
  default     = "subnet-ubuntu"
}

variable "subnet_prefix" {
  description = "CIDR block untuk Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vms" {
  description = "Definisi setiap VM: peran, ukuran, dan apakah expose port 8080"
  type = map(object({
    role      = string
    size      = string
    open_8080 = bool
    open_80   = bool
  }))
  default = {
    jenkins = {
      role      = "jenkins-node"
      size      = "Standard_D2s_v3"
      open_8080 = true
      open_80   = false
    }
    target = {
      role      = "target-node"
      size      = "Standard_D2s_v3"
      open_8080 = false
      open_80   = true
    }
  }
}

variable "admin_username" {
  description = "Nama user administrator untuk login SSH ke VM"
  type        = string
  default     = "azureuser"
}

variable "os_disk_type" {
  description = "Tipe storage OS disk (Standard_LRS = HDD | Premium_LRS = SSD)"
  type        = string
  default     = "Standard_LRS"
}

variable "tags" {
  description = "Tag yang diterapkan ke semua resource"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "UbuntuLab"
    Owner       = "DevOps Team"
    ManagedBy   = "Terraform"
  }
}
