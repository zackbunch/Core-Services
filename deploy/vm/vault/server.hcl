ui = true

# Raft storage persists across restarts. This is one node, not an HA deployment.
# Disable swap on the VM when operating Vault without mlock.
disable_mlock = true

storage "raft" {
  path    = "/vault/data"
  node_id = "coreservices-vault-1"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  # HTTP is private to the Compose network; Caddy terminates external HTTPS.
  tls_disable = 1
}

cluster_addr = "https://vault:8201"
# VAULT_API_ADDR supplies the externally reachable URL from compose.yaml.
