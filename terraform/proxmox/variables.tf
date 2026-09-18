variable "proxmox_endpoint" {
  description = "Trusted Proxmox HTTPS API URL, including port 8006 and trailing slash."
  type        = string
  validation {
    condition     = can(regex("^https://[^/@]+(:[0-9]+)?/$", var.proxmox_endpoint))
    error_message = "Use an HTTPS API endpoint such as https://pve.example.com:8006/."
  }
}

variable "proxmox_node" {
  description = "Exact Proxmox node name on which to create the VM."
  type        = string
}

variable "proxmox_ssh_username" {
  description = "Node SSH user permitted to upload snippets (distinct from the VM login user)."
  type        = string
  default     = "root"
}

variable "vm_id" {
  description = "An unused Proxmox VM ID; null lets the provider allocate one."
  type        = number
  default     = null
  validation {
    condition     = var.vm_id == null ? true : var.vm_id >= 100 && floor(var.vm_id) == var.vm_id
    error_message = "VM ID must be an integer of at least 100, or null."
  }
}

variable "vm_name" {
  description = "VM name and cloud-init hostname."
  type        = string
  default     = "coreservices-dev"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.vm_name))
    error_message = "Use a lowercase hostname, 2-63 characters, without a trailing hyphen."
  }
}

variable "vm_datastore_id" {
  description = "Proxmox storage for the OS and cloud-init disks, with images content enabled."
  type        = string
  default     = "local-lvm"
}

variable "image_datastore_id" {
  description = "File-backed Proxmox storage with ISO content enabled, for the downloaded cloud image."
  type        = string
  default     = "local"
}

variable "snippet_datastore_id" {
  description = "File-backed Proxmox storage with snippets content enabled, for cloud-init user data."
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Existing LAN/VPN-accessible Proxmox bridge. This configuration creates no public port forwards."
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "Optional VLAN tag; the bridge must already support it."
  type        = number
  default     = null
  validation {
    condition     = var.vlan_id == null ? true : var.vlan_id >= 1 && var.vlan_id <= 4094 && floor(var.vlan_id) == var.vlan_id
    error_message = "VLAN ID must be 1-4094 or null."
  }
}

variable "ipv4_address" {
  description = "dhcp, or a static IPv4 address with CIDR prefix, e.g. 192.168.10.50/24. Reserve DHCP leases on your router."
  type        = string
  default     = "dhcp"
  validation {
    condition     = var.ipv4_address == "dhcp" || (can(cidrnetmask(var.ipv4_address)) && can(regex("/", var.ipv4_address)))
    error_message = "Use dhcp or a valid IPv4 CIDR address."
  }
}

variable "ipv4_gateway" {
  description = "Gateway for static IPv4 configuration; leave null for DHCP."
  type        = string
  default     = null
  validation {
    condition     = var.ipv4_gateway == null ? true : can(cidrnetmask("${var.ipv4_gateway}/32"))
    error_message = "Gateway must be a valid IPv4 address or null."
  }
}

variable "dns_servers" {
  description = "Optional DNS servers; for internal service names, supply your LAN DNS servers. Empty uses inherited defaults."
  type        = list(string)
  default     = []
}

variable "ssh_username" {
  description = "Non-root VM login user created by cloud-init, with passwordless sudo."
  type        = string
  default     = "admin"
  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,30}$", var.ssh_username)) && var.ssh_username != "root"
    error_message = "Use a valid non-root Linux username."
  }
}

variable "ssh_public_keys" {
  description = "Authorized public SSH keys for the VM login user. Never put private keys here."
  type        = list(string)
  validation {
    condition = length(var.ssh_public_keys) > 0 && alltrue([
      for key in var.ssh_public_keys : can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+) [A-Za-z0-9+/=]+", trimspace(key)))
    ])
    error_message = "Supply at least one OpenSSH public key."
  }
}

variable "ubuntu_image_url" {
  description = "Ubuntu 24.04 amd64 cloud image. Pin a dated Ubuntu release URL for reproducible deployments."
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  validation {
    condition     = startswith(var.ubuntu_image_url, "https://")
    error_message = "Download the image over HTTPS."
  }
}

variable "ubuntu_image_sha256" {
  description = "Optional SHA256 from Ubuntu's signed SHA256SUMS for the exact image URL. Recommended with a pinned image URL."
  type        = string
  default     = null
  validation {
    condition     = var.ubuntu_image_sha256 == null ? true : can(regex("^[0-9a-fA-F]{64}$", var.ubuntu_image_sha256))
    error_message = "Provide a 64-character hexadecimal SHA256 or null."
  }
}
