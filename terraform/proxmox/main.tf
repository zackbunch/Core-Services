resource "proxmox_virtual_environment_download_file" "ubuntu" {
  node_name          = var.proxmox_node
  datastore_id       = var.image_datastore_id
  content_type       = "iso"
  file_name          = "${var.vm_name}-ubuntu-24.04-amd64.img"
  url                = var.ubuntu_image_url
  checksum           = var.ubuntu_image_sha256
  checksum_algorithm = var.ubuntu_image_sha256 == null ? null : "sha256"
}

resource "proxmox_virtual_environment_file" "cloud_init" {
  node_name    = var.proxmox_node
  datastore_id = var.snippet_datastore_id
  content_type = "snippets"

  source_raw {
    file_name = "${var.vm_name}-cloud-init.yaml"
    data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname        = var.vm_name
      username        = var.ssh_username
      ssh_public_keys = var.ssh_public_keys
    })
  }
}

resource "proxmox_virtual_environment_vm" "core_services" {
  node_name   = var.proxmox_node
  vm_id       = var.vm_id
  name        = var.vm_name
  description = "Ubuntu 24.04 CoreServices development VM, managed by Terraform"
  tags        = ["terraform", "coreservices", "development"]
  started     = true
  on_boot     = true
  boot_order  = ["scsi0"]

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }

  disk {
    datastore_id = var.vm_datastore_id
    interface    = "scsi0"
    file_id      = proxmox_virtual_environment_download_file.ubuntu.id
    size         = 80
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  serial_device {}

  initialization {
    datastore_id      = var.vm_datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [var.dns_servers] : []
      content {
        servers = dns.value
      }
    }

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }
  }

  lifecycle {
    # Safeguard the VM's future persistent service data. Destruction/replacement
    # requires an explicit code change and a backup review first.
    prevent_destroy = true

    precondition {
      condition     = (var.ipv4_address == "dhcp") == (var.ipv4_gateway == null)
      error_message = "Use a gateway with a static address; leave it null for DHCP."
    }
  }
}
