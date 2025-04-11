# Authentication Service policy for Vault
# Allows the authentication service to access only its specific secrets

# Allow reading authentication service secrets
path "secret/data/authentication-service/*" {
  capabilities = ["read", "list"]
}

# Allow reading AWS credentials for Cognito access
path "aws/creds/authentication-service" {
  capabilities = ["read"]
}

# Allow the service to renew its token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow the service to look up its token info
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
