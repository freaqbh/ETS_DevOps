# =============================================================================
# TERRAFORM AZURE - Jenkins Node & Target Node
# =============================================================================
# Deskripsi : Provisioning infrastruktur Azure berisi:
#               - 1 Resource Group
#               - 1 Virtual Network (VNet)
#               - 1 Subnet
#               - 2 NSG per-VM (Jenkins: port 22 & 8080 | Target: port 22 saja)
#               - 2 Public IP Address
#               - 2 Network Interface Card (NIC)
#               - 2 VM Ubuntu 22.04 LTS (Jenkins Node & Target Node)
#               - SSH Key otomatis via TLS provider (tanpa password)
#               - Remote Backend: Azure Blob Storage (state management)
# Versi TF  : >= 1.3.0
# Provider  : hashicorp/azurerm ~> 3.0 | hashicorp/tls ~> 4.0
# =============================================================================


# =============================================================================
# TERRAFORM BLOCK
# FIX #2 — Remote Backend untuk State File Management
# State disimpan di Azure Blob Storage agar:
#   - Tidak hilang jika mesin lokal rusak
#   - Bisa diakses bersama oleh tim (shared state)
#   - Mendukung state locking via Blob lease (mencegah concurrent apply)
#
# PRASYARAT — Buat storage account terlebih dahulu (cukup sekali):
#   az group create --name rg-tfstate --location "Southeast Asia"
#   az storage account create --name satfstatedevopskel1 --resource-group rg-tfstate \
#     --sku Standard_LRS --encryption-services blob
#   az storage container create --name tfstate --account-name satfstatedevopskel1
# =============================================================================
terraform {
  required_version = ">= 1.3.0"

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-baru"              # RG khusus untuk menyimpan state
    storage_account_name = "satfstatekel1abhinaya"        # GANTI: harus globally unique di Azure
    container_name       = "tfstate"                      # Container blob
    key                  = "ubuntu-lab.terraform.tfstate" # Nama file state
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    # FIX #3 — Provider TLS untuk generate SSH key pair secara otomatis
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Provider local untuk menyimpan private key ke disk lokal
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# =============================================================================
# PROVIDER CONFIGURATION
# =============================================================================
provider "azurerm" {
  features {}
  # Untuk CI/CD gunakan environment variable:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
}


# =============================================================================
# FIX #3 — SSH KEY PAIR (Menggantikan password authentication)
# TLS provider generate RSA 4096-bit key pair secara otomatis saat `apply`
# Public key  → dikirim ke Azure (disimpan di VM ~/.ssh/authorized_keys)
# Private key → disimpan lokal sebagai file .pem (sekali unduh, jaga baik-baik)
# =============================================================================
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Simpan private key ke file lokal — digunakan untuk SSH ke semua VM
# Jalankan: chmod 600 ./ssh_private_key.pem  (setelah terraform apply)
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/ssh_private_key.pem"
  file_permission = "0600" # Hanya owner yang bisa baca (wajib untuk SSH client)
}


# =============================================================================
# RESOURCE GROUP
# =============================================================================
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}


# =============================================================================
# NETWORKING
# =============================================================================

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

# Subnet — satu subnet untuk semua VM (NSG dikontrol di level NIC)
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefix]
}

# -----------------------------------------------------------------------------
# FIX #1 — NSG Per-VM dengan aturan berbeda
# Jenkins NSG : Allow port 22 (SSH) + 8080 (Jenkins UI)
# Target NSG  : Allow port 22 (SSH) saja — tidak perlu expose 8080
#
# NSG diasosiasikan ke NIC (bukan subnet) agar kontrol lebih granular per-VM
# dynamic block digunakan agar rule 8080 hanya muncul jika open_8080 = true
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.vms
  name                = "nsg-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # ---- RULE 1: SSH (Port 22) — berlaku untuk semua VM ----------------------
  # REKOMENDASI PRODUKSI: Ganti source_address_prefix dengan IP spesifik Anda
  # Contoh: source_address_prefix = "203.0.113.10/32"
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # ---- RULE 2: Port 8080 — HANYA untuk Jenkins Node -----------------------
  # dynamic block: rule ini hanya dibuat jika open_8080 = true
  dynamic "security_rule" {
    for_each = each.value.open_8080 ? [1] : [] # [1] = buat rule | [] = skip
    content {
      name                       = "Allow-Jenkins-8080"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "8080"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  dynamic "security_rule" {
    for_each = each.value.open_80 ? [1] : []
    content {
      name                       = "Allow-HTTP-80"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # ---- RULE 3: Deny semua traffic inbound lain ----------------------------
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, { Role = each.value.role })
}


# =============================================================================
# PUBLIC IP ADDRESS — satu per VM
# =============================================================================
resource "azurerm_public_ip" "public_ip" {
  for_each            = var.vms
  name                = "pip-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(var.tags, { Role = each.value.role })
}


# =============================================================================
# NETWORK INTERFACE CARD (NIC)
# =============================================================================
resource "azurerm_network_interface" "nic" {
  for_each            = var.vms
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-${each.key}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[each.key].id
  }

  tags = merge(var.tags, { Role = each.value.role })
}

# Asosiasikan NSG ke NIC masing-masing VM (bukan ke subnet)
# Ini memastikan Jenkins dan Target mendapat rule yang berbeda
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  for_each                  = var.vms
  network_interface_id      = azurerm_network_interface.nic[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}


# =============================================================================
# VIRTUAL MACHINES
# FIX #1 — Nama VM mencerminkan peran (vm-jenkins, vm-target)
# FIX #3 — Menggunakan SSH key, password authentication dinonaktifkan
# =============================================================================
resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = var.vms
  name                = "vm-${each.key}" # vm-jenkins | vm-target
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = each.value.size

  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  admin_username = var.admin_username

  # FIX #3 — SSH Key Authentication (password dinonaktifkan sepenuhnya)
  # Public key yang di-generate oleh resource tls_private_key.ssh di atas
  disable_password_authentication = true # Password auth dimatikan = lebih aman
  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    name                 = "osdisk-${each.key}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name = each.key # hostname: "jenkins" atau "target"

  boot_diagnostics {
    storage_account_uri = null # Managed storage Azure (gratis)
  }

  tags = merge(var.tags, { Role = each.value.role })

  depends_on = [azurerm_network_interface_security_group_association.nic_nsg]
}
