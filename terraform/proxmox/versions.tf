terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  # Read the API token from PROXMOX_VE_API_TOKEN, not a checked-in tfvars file.
  insecure = false

  # The provider needs SSH/SFTP for uploading the cloud-init snippet.
  # Load the node's authorized private key into your local ssh-agent first.
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
