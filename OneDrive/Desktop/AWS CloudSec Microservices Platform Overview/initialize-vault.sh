#!/bin/bash
# Script to initialize and configure HashiCorp Vault

# Set environment variables
export VAULT_ADDR="https://vault.cloudsec-platform.internal:8200"

# Initialize Vault
echo "Initializing Vault..."
vault operator init > /tmp/vault-init.txt

# Extract unseal keys and root token
UNSEAL_KEY_1=$(grep "Unseal Key 1" /tmp/vault-init.txt | awk '{print $NF}')
UNSEAL_KEY_2=$(grep "Unseal Key 2" /tmp/vault-init.txt | awk '{print $NF}')
UNSEAL_KEY_3=$(grep "Unseal Key 3" /tmp/vault-init.txt | awk '{print $NF}')
ROOT_TOKEN=$(grep "Initial Root Token" /tmp/vault-init.txt | awk '{print $NF}')

# Unseal Vault
echo "Unsealing Vault..."
vault operator unseal $UNSEAL_KEY_1
vault operator unseal $UNSEAL_KEY_2
vault operator unseal $UNSEAL_KEY_3

# Authenticate with root token
echo "Authenticating with root token..."
vault login $ROOT_TOKEN

# Enable audit logging
echo "Enabling audit logging..."
vault audit enable file file_path=/var/log/vault/audit.log

# Enable secrets engines
echo "Enabling secrets engines..."
vault secrets enable -path=secret kv-v2
vault secrets enable aws

# Configure AWS secrets engine
echo "Configuring AWS secrets engine..."
vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY \
    secret_key=$AWS_SECRET_KEY \
    region=us-east-1

# Create AWS roles for services
echo "Creating AWS roles for services..."
vault write aws/roles/authentication-service \
    credential_type=iam_user \
    policy_document=@/vault/aws-policies/authentication-service-policy.json

vault write aws/roles/business-service \
    credential_type=iam_user \
    policy_document=@/vault/aws-policies/business-service-policy.json

# Create policies
echo "Creating policies..."
vault policy write admin /vault/policies/admin-policy.hcl
vault policy write authentication-service /vault/policies/authentication-service-policy.hcl
vault policy write business-service /vault/policies/business-service-policy.hcl
vault policy write frontend-service /vault/policies/frontend-service-policy.hcl

# Enable AppRole auth method
echo "Enabling AppRole auth method..."
vault auth enable approle

# Create AppRoles for services
echo "Creating AppRoles for services..."
vault write auth/approle/role/authentication-service \
    token_policies=authentication-service \
    token_ttl=1h \
    token_max_ttl=24h

vault write auth/approle/role/business-service \
    token_policies=business-service \
    token_ttl=1h \
    token_max_ttl=24h

vault write auth/approle/role/frontend-service \
    token_policies=frontend-service \
    token_ttl=1h \
    token_max_ttl=24h

# Get RoleIDs and SecretIDs for services
echo "Getting RoleIDs and SecretIDs for services..."
vault read auth/approle/role/authentication-service/role-id > /tmp/auth-service-role-id.txt
vault write -f auth/approle/role/authentication-service/secret-id > /tmp/auth-service-secret-id.txt

vault read auth/approle/role/business-service/role-id > /tmp/business-service-role-id.txt
vault write -f auth/approle/role/business-service/secret-id > /tmp/business-service-secret-id.txt

vault read auth/approle/role/frontend-service/role-id > /tmp/frontend-service-role-id.txt
vault write -f auth/approle/role/frontend-service/secret-id > /tmp/frontend-service-secret-id.txt

# Store initial secrets
echo "Storing initial secrets..."
vault kv put secret/authentication-service/config \
    cognito_user_pool_id="us-east-1_examplepool" \
    cognito_client_id="example-client-id" \
    jwt_secret="initial-jwt-secret-to-be-rotated"

vault kv put secret/business-service/config \
    dynamodb_table="cloudsec-business-items" \
    api_key="initial-api-key-to-be-rotated"

vault kv put secret/frontend-service/config \
    auth_service_url="https://auth.cloudsec-platform.internal" \
    business_service_url="https://business.cloudsec-platform.internal"

vault kv put secret/api-endpoints/urls \
    auth_service="https://auth.cloudsec-platform.internal" \
    business_service="https://business.cloudsec-platform.internal" \
    frontend_service="https://app.cloudsec-platform.internal"

echo "Vault initialization and configuration completed!"
