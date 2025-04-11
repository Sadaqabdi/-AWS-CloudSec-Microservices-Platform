#!/bin/bash
# Script to implement secret rotation for HashiCorp Vault

# Set environment variables
export VAULT_ADDR="https://vault.cloudsec-platform.internal:8200"

# Function to check if Vault is unsealed and accessible
check_vault_status() {
  echo "Checking Vault status..."
  vault status > /dev/null
  if [ $? -ne 0 ]; then
    echo "Error: Vault is not accessible. Please check Vault status and authentication."
    exit 1
  fi
}

# Function to rotate AWS credentials
rotate_aws_credentials() {
  local service=$1
  echo "Rotating AWS credentials for $service..."
  
  # Revoke old credentials
  vault list aws/creds/$service | while read -r lease_id; do
    if [ ! -z "$lease_id" ]; then
      vault lease revoke aws/creds/$service/$lease_id
    fi
  done
  
  # Generate new credentials
  vault read aws/creds/$service
  echo "AWS credentials rotated for $service"
}

# Function to rotate service secrets
rotate_service_secrets() {
  local service=$1
  echo "Rotating secrets for $service..."
  
  # Generate new random values
  local new_api_key=$(openssl rand -base64 32)
  local new_jwt_secret=$(openssl rand -base64 32)
  
  # Update secrets based on service type
  case $service in
    authentication-service)
      vault kv put secret/$service/config \
        cognito_user_pool_id=$(vault kv get -field=cognito_user_pool_id secret/$service/config) \
        cognito_client_id=$(vault kv get -field=cognito_client_id secret/$service/config) \
        jwt_secret=$new_jwt_secret
      ;;
    business-service)
      vault kv put secret/$service/config \
        dynamodb_table=$(vault kv get -field=dynamodb_table secret/$service/config) \
        api_key=$new_api_key
      ;;
    frontend-service)
      # Frontend service typically doesn't have secrets that need rotation
      # Just re-write the existing configuration
      vault kv put secret/$service/config \
        auth_service_url=$(vault kv get -field=auth_service_url secret/$service/config) \
        business_service_url=$(vault kv get -field=business_service_url secret/$service/config)
      ;;
    *)
      echo "Unknown service: $service"
      return 1
      ;;
  esac
  
  echo "Secrets rotated for $service"
}

# Function to rotate AppRole credentials
rotate_approle_credentials() {
  local service=$1
  echo "Rotating AppRole credentials for $service..."
  
  # Generate new SecretID
  vault write -f auth/approle/role/$service/secret-id > /tmp/$service-new-secret-id.txt
  
  # Extract the new SecretID
  local new_secret_id=$(grep "secret_id " /tmp/$service-new-secret-id.txt | awk '{print $2}')
  
  echo "AppRole credentials rotated for $service"
  echo "New SecretID saved to /tmp/$service-new-secret-id.txt"
  
  # In a real environment, you would securely distribute this to the service
  # For example, using Kubernetes secrets or AWS Secrets Manager
}

# Main execution
main() {
  # Check arguments
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <service-name> [--all]"
    echo "  service-name: authentication-service, business-service, or frontend-service"
    echo "  --all: Rotate credentials for all services"
    exit 1
  fi
  
  # Check Vault status
  check_vault_status
  
  # Process based on arguments
  if [ "$1" == "--all" ]; then
    # Rotate for all services
    for service in authentication-service business-service frontend-service; do
      rotate_aws_credentials $service
      rotate_service_secrets $service
      rotate_approle_credentials $service
    done
  else
    # Rotate for specific service
    rotate_aws_credentials $1
    rotate_service_secrets $1
    rotate_approle_credentials $1
  fi
  
  echo "Secret rotation completed successfully!"
}

# Execute main function
main "$@"
