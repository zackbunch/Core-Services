output "vm_id" {
  description = "Allocated Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.core_services.vm_id
}

output "vm_name" {
  value = proxmox_virtual_environment_vm.core_services.name
}

output "ipv4_addresses" {
  description = "Guest-agent reported addresses, possibly including loopback/container interfaces. May be empty until first boot finishes."
  value       = proxmox_virtual_environment_vm.core_services.ipv4_addresses
}

output "mac_addresses" {
  description = "Use the LAN NIC MAC address to create a DHCP reservation."
  value       = proxmox_virtual_environment_vm.core_services.mac_addresses
}

output "ssh_user" {
  value = var.ssh_username
}

output "static_ssh_command" {
  description = "For DHCP, use a reported LAN address or the reservation from your router."
  value       = var.ipv4_address == "dhcp" ? null : "ssh ${var.ssh_username}@${split("/", var.ipv4_address)[0]}"
}
