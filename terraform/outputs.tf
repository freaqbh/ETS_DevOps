output "jenkins_vm_public_ip" {
  description = "Public IP Jenkins Server"
  value       = azurerm_public_ip.public_ip["jenkins"].ip_address
}

output "worker_vm_public_ip" {
  description = "Public IP Target Worker Server"
  value       = azurerm_public_ip.public_ip["target"].ip_address
}

output "resource_group_name" {
  description = "Nama Resource Group yang dibuat"
  value       = azurerm_resource_group.rg.name
}

output "virtual_network_name" {
  description = "Nama Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "vm_details" {
  description = "Detail setiap VM: nama, peran, public IP, dan private IP"
  value = {
    for key, vm in azurerm_linux_virtual_machine.vm : key => {
      name       = vm.name
      role       = var.vms[key].role
      public_ip  = azurerm_public_ip.public_ip[key].ip_address
      private_ip = azurerm_network_interface.nic[key].private_ip_address
      size       = vm.size
    }
  }
}

output "ssh_commands" {
  description = "Perintah SSH siap pakai (gunakan file private key yang di-generate)"
  value = {
    for key, pip in azurerm_public_ip.public_ip :
    key => "ssh -i ./ssh_private_key.pem ${var.admin_username}@${pip.ip_address}"
  }
}

output "jenkins_url" {
  description = "URL akses Jenkins UI (tersedia setelah Jenkins terinstall di VM)"
  value       = "http://${azurerm_public_ip.public_ip["jenkins"].ip_address}:8080"
}

output "nsg_rules_summary" {
  description = "Ringkasan aturan NSG per VM"
  value = {
    for key, vm in var.vms :
    key => vm.open_8080 ? "Port 22 (SSH) + Port 8080 (Jenkins)" : "Port 22 (SSH) only"
  }
}

output "ssh_public_key" {
  description = "SSH Public Key yang terpasang di semua VM"
  value       = tls_private_key.ssh.public_key_openssh
  sensitive   = false
}

output "ssh_private_key_path" {
  description = "Lokasi file SSH Private Key (jaga kerahasiaannya!)"
  value       = local_sensitive_file.private_key.filename
}