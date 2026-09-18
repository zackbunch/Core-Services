# Mocked plans only: no connection to Proxmox and no VM creation.
mock_provider "proxmox" {}

variables {
  proxmox_endpoint = "https://pve.example.test:8006/"
  proxmox_node     = "pve-test"
  ssh_public_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureOnlyNotARealAuthorizedKey fixture"
  ]
}

run "default_vm" {
  command = plan

  assert {
    condition     = proxmox_virtual_environment_vm.core_services.cpu[0].cores == 4 && proxmox_virtual_environment_vm.core_services.memory[0].dedicated == 8192 && proxmox_virtual_environment_vm.core_services.disk[0].size == 80
    error_message = "Expected a 4-vCPU, 8-GiB, 80-GiB VM."
  }

  assert {
    condition     = proxmox_virtual_environment_vm.core_services.initialization[0].ip_config[0].ipv4[0].address == "dhcp"
    error_message = "Default network configuration must use DHCP."
  }

  assert {
    condition     = yamldecode(proxmox_virtual_environment_file.cloud_init.source_raw[0].data).ssh_pwauth == false && yamldecode(proxmox_virtual_environment_file.cloud_init.source_raw[0].data).disable_root == true
    error_message = "VM SSH must disable password and root login."
  }

  assert {
    condition     = yamldecode(proxmox_virtual_environment_file.cloud_init.source_raw[0].data).users[0].ssh_authorized_keys[0] == var.ssh_public_keys[0]
    error_message = "Public key must be preserved safely in cloud-init YAML."
  }

  assert {
    condition     = strcontains(yamldecode(proxmox_virtual_environment_file.cloud_init.source_raw[0].data).write_files[0].content, "docker-compose-plugin")
    error_message = "Docker Compose plugin must be included in bootstrap."
  }
}

run "static_network" {
  command = plan
  variables {
    ipv4_address = "192.168.10.50/24"
    ipv4_gateway = "192.168.10.1"
    dns_servers  = ["192.168.10.1"]
    vlan_id      = 20
  }
  assert {
    condition     = output.static_ssh_command == "ssh admin@192.168.10.50"
    error_message = "SSH output must use the static address without CIDR suffix."
  }
}

run "reject_static_without_gateway" {
  command = plan
  variables {
    ipv4_address = "192.168.10.50/24"
  }
  expect_failures = [proxmox_virtual_environment_vm.core_services]
}

run "reject_insecure_api" {
  command = plan
  variables {
    proxmox_endpoint = "http://pve.example.test:8006/"
  }
  expect_failures = [var.proxmox_endpoint]
}

run "reject_missing_public_keys" {
  command = plan
  variables {
    ssh_public_keys = []
  }
  expect_failures = [var.ssh_public_keys]
}
