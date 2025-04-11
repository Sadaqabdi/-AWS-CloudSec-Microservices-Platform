# Admin policy for Vault administrators
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow managing auth methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow managing secret engines
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow managing policies
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow listing and creating tokens
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow managing audit devices
path "sys/audit*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
