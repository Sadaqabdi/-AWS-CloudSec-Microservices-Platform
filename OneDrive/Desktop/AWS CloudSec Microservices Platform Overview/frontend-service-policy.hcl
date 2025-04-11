# Frontend Service policy for Vault
# Allows the frontend service to access only its specific secrets

# Allow reading frontend service secrets
path "secret/data/frontend-service/*" {
  capabilities = ["read", "list"]
}

# Allow reading API endpoints configuration
path "secret/data/api-endpoints/*" {
  capabilities = ["read", "list"]
}

# Allow the service to renew its token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow the service to look up its token info
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
