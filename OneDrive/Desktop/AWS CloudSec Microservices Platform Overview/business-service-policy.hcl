# Business Service policy for Vault
# Allows the business service to access only its specific secrets

# Allow reading business service secrets
path "secret/data/business-service/*" {
  capabilities = ["read", "list"]
}

# Allow reading and writing sensitive business data
path "secret/data/business/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow reading AWS credentials for DynamoDB access
path "aws/creds/business-service" {
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
