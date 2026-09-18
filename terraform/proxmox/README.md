# CoreServices development VM on Proxmox

Creates **one Ubuntu Server 24.04 LTS VM** with:

- 4 vCPU (`host` CPU type), 8 GiB RAM, and an 80 GiB OS disk.
- SSH public-key login for a non-root user (`admin` by default).
- Root SSH and password SSH disabled; the admin user has passwordless sudo.
- QEMU guest agent, Docker Engine, Buildx, and the Docker Compose plugin.
- DHCP by default, or an explicit static IPv4 address, gateway, and DNS servers.
- Boot-on-host-start enabled and a Terraform `prevent_destroy` safeguard.

This is VM provisioning only. It does **not** copy this repository, start the
service containers, configure DNS/Caddy, migrate data, configure Vault, or open
router ports. In particular, the existing in-memory development Vault is not
made durable by moving it to a VM.

## Prerequisites

1. An x86-64 Proxmox VE host compatible with the pinned `bpg/proxmox` provider.
   Confirm the node name, available VM IDs, bridge, VLAN, and storage IDs.
2. Terraform **1.7+** (below 2.0), SSH/SFTP access to the node, and Internet access
   from Proxmox (Ubuntu image download) and the guest (Ubuntu/Docker packages).
3. A dedicated Proxmox API token, in `user@realm!token-id=secret` format, with
   permissions for the resources in this module. Scope it to the intended node,
   VM/storage paths. Image downloads, VM allocation/configuration, and disk import
   require more than read-only permissions. Consult the pinned provider's
   permission documentation for your Proxmox version; avoid a broadly privileged
   personal admin token. With privilege separation enabled, both user and token
   permissions must allow the operations.
4. API certificate trust on the machine running Terraform. Use a trusted Proxmox
   certificate or install its CA locally. TLS verification is not disabled.
5. An SSH key loaded in your local `ssh-agent`, authorized for the Proxmox node's
   SSH user. This is **separate** from the public key installed inside the VM.
   The provider uses node SSH for snippet upload and image/disk operations. The
   default node user is `root`; a different user must have the necessary supported
   permissions. Verify host identity before accepting SSH host keys.
6. File-backed storage with **ISO** content enabled for the Ubuntu image and
   **Snippets** content enabled for cloud-init. These default to `local`. Enable
   Snippets in **Datacenter → Storage → local → Edit → Content**, preserving the
   storage's existing content types. VM disks default to `local-lvm`, which must
   support disk images. Adjust all three IDs for your host.

Use a LAN/VPN-only bridge or a suitably restricted VLAN. This module does not
create firewall rules; do not attach it to an unprotected public network. Docker
published ports need explicit network/firewall review when deploying services.
Do not assume UFW alone restricts Docker-published ports.

Provider documentation: https://registry.terraform.io/providers/bpg/proxmox/0.78.2/docs

## Configure

From this directory:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit the example endpoint, node, storage, bridge, and public key. The placeholder
key is intentionally not usable. For example, copy the contents of your public
`~/.ssh/id_ed25519.pub` file, never the private key.

Load your authorized **Proxmox node** key into the agent:

```bash
ssh-add ~/.ssh/id_ed25519
ssh root@YOUR_PROXMOX_NODE
```

Exit the node shell before running Terraform. Choose a different SSH identity or
username if required by your host.

Supply the API token without putting it into source control or a shell-history
literal (the following reads it silently):

```bash
printf 'Proxmox API token: '
read -r -s PROXMOX_VE_API_TOKEN
printf '\n'
export PROXMOX_VE_API_TOKEN
```

Use a password manager or your normal secret-injection mechanism where available.
Do not commit the token, private keys, plan files, state files, or real `.tfvars`.
This directory defaults to local state; protect and back it up. For shared use,
configure an encrypted remote backend with state locking before multiple operators
manage the same infrastructure. The provider lock file is intentionally committed.

## Validate and deploy

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform test             # Mocked plans; no live Proxmox changes
terraform plan -out=vm.tfplan
terraform apply vm.tfplan  # Creates real infrastructure: review the plan first
```

No live plan/apply has been tested without your Proxmox settings and credentials.
The mock tests verify defaults, networking, rendered cloud-init, and invalid-input
rejection, not compatibility with your particular host or live package installs.

Use a dated Ubuntu cloud-image URL plus the corresponding verified SHA256 for
repeatable deployments. The default `noble/current` URL is convenient but mutable;
Terraform does not automatically detect changes to the content at an unchanged URL.
Changing image/snippet settings can affect an existing VM: inspect plans carefully.
The VM's `prevent_destroy` blocks Terraform destruction/replacement while configured;
remove it only deliberately after backup review. It is not a backup mechanism.

## First boot

Image download and cloud-init package installation can take several minutes.
Find the VM's LAN IP in Proxmox, your DHCP server, or Terraform outputs:

```bash
terraform output ipv4_addresses
terraform output mac_addresses
ssh admin@VM_LAN_IP
sudo cloud-init status --wait
sudo systemctl status qemu-guest-agent docker
sudo docker version
sudo docker compose version
```

The IP output can contain multiple interfaces and may initially be empty. With
DHCP, reserve the LAN NIC's MAC address in your router before assigning internal
DNS names. With static addressing, select an unused IP and the correct gateway.
No DNS records or DHCP reservations are created by this module.

Terraform provisioning success is not proof that Docker installation finished:
check `cloud-init status` and `/var/log/cloud-init-output.log` on the VM. A network
or package error may require correction and rerunning the relevant bootstrap step.
Cloud-init runs initial provisioning once; editing user data is not ongoing
configuration management and may not rerun on an existing guest. Review whether
security updates require a reboot after provisioning.

An optional SSH alias on your workstation:

```sshconfig
Host coreservices
    HostName VM_LAN_IP
    User admin
    IdentityFile ~/.ssh/id_ed25519
```

## Next steps

1. Assign reachable internal DNS names (not `.localhost`) and trusted HTTPS.
2. Copy the Compose project and configure service secrets outside Git.
3. Plan data migration and persistent Vault storage before starting services.
4. Restrict service access, configure scheduled backups, and test restores.
5. Point Arsenal on both the Mac and devbox at the new Keycloak issuer.

Moving services fixes reachability. It does not supply devbox with a browser or
Linux keyring, and it does not implement device authorization in the CLI.
