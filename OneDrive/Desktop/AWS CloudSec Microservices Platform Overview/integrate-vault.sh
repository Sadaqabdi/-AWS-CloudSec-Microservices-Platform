#!/bin/bash
# Script to integrate HashiCorp Vault with microservices

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

# Function to create Vault integration configuration for a service
create_vault_integration_config() {
  local service=$1
  local config_dir=$2
  
  echo "Creating Vault integration configuration for $service..."
  
  # Get RoleID and SecretID for the service
  local role_id=$(vault read -field=role_id auth/approle/role/$service/role-id)
  local secret_id=$(vault write -f -field=secret_id auth/approle/role/$service/secret-id)
  
  # Create Vault agent configuration
  cat > $config_dir/vault-agent.hcl << EOF
pid_file = "/var/run/vault-agent.pid"

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path = "/vault/config/role-id"
      secret_id_file_path = "/vault/config/secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "/vault/token/vault-token"
    }
  }
}

template {
  source = "/vault/templates/config.tpl"
  destination = "/vault/secrets/config.json"
}

vault {
  address = "$VAULT_ADDR"
}
EOF

  # Create role-id and secret-id files
  echo $role_id > $config_dir/role-id
  echo $secret_id > $config_dir/secret-id
  
  # Create template file based on service type
  mkdir -p $config_dir/templates
  
  case $service in
    authentication-service)
      cat > $config_dir/templates/config.tpl << EOF
{
  "cognito": {
    "userPoolId": "{{ with secret "secret/data/authentication-service/config" }}{{ .Data.data.cognito_user_pool_id }}{{ end }}",
    "clientId": "{{ with secret "secret/data/authentication-service/config" }}{{ .Data.data.cognito_client_id }}{{ end }}"
  },
  "jwt": {
    "secret": "{{ with secret "secret/data/authentication-service/config" }}{{ .Data.data.jwt_secret }}{{ end }}"
  },
  "aws": {
    "region": "us-east-1",
    "credentials": {
      "accessKey": "{{ with secret "aws/creds/authentication-service" }}{{ .Data.access_key }}{{ end }}",
      "secretKey": "{{ with secret "aws/creds/authentication-service" }}{{ .Data.secret_key }}{{ end }}"
    }
  }
}
EOF
      ;;
    business-service)
      cat > $config_dir/templates/config.tpl << EOF
{
  "database": {
    "dynamoDb": {
      "table": "{{ with secret "secret/data/business-service/config" }}{{ .Data.data.dynamodb_table }}{{ end }}"
    }
  },
  "api": {
    "key": "{{ with secret "secret/data/business-service/config" }}{{ .Data.data.api_key }}{{ end }}"
  },
  "aws": {
    "region": "us-east-1",
    "credentials": {
      "accessKey": "{{ with secret "aws/creds/business-service" }}{{ .Data.access_key }}{{ end }}",
      "secretKey": "{{ with secret "aws/creds/business-service" }}{{ .Data.secret_key }}{{ end }}"
    }
  }
}
EOF
      ;;
    frontend-service)
      cat > $config_dir/templates/config.tpl << EOF
{
  "api": {
    "authServiceUrl": "{{ with secret "secret/data/api-endpoints/urls" }}{{ .Data.data.auth_service }}{{ end }}",
    "businessServiceUrl": "{{ with secret "secret/data/api-endpoints/urls" }}{{ .Data.data.business_service }}{{ end }}"
  }
}
EOF
      ;;
    *)
      echo "Unknown service: $service"
      return 1
      ;;
  esac
  
  echo "Vault integration configuration created for $service"
}

# Main execution
main() {
  # Check arguments
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <service-name> <config-directory> [--all]"
    echo "  service-name: authentication-service, business-service, or frontend-service"
    echo "  config-directory: Directory to store Vault integration configuration"
    echo "  --all: Create configuration for all services"
    exit 1
  fi
  
  # Check Vault status
  check_vault_status
  
  # Process based on arguments
  if [ "$1" == "--all" ]; then
    # Create configuration for all services
    mkdir -p /home/ubuntu/aws-cloudsec-microservices/vault/integration/authentication-service
    mkdir -p /home/ubuntu/aws-cloudsec-microservices/vault/integration/business-service
    mkdir -p /home/ubuntu/aws-cloudsec-microservices/vault/integration/frontend-service
    
    create_vault_integration_config "authentication-service" "/home/ubuntu/aws-cloudsec-microservices/vault/integration/authentication-service"
    create_vault_integration_config "business-service" "/home/ubuntu/aws-cloudsec-microservices/vault/integration/business-service"
    create_vault_integration_config "frontend-service" "/home/ubuntu/aws-cloudsec-microservices/vault/integration/frontend-service"
  else
    # Create configuration for specific service
    mkdir -p $2
    create_vault_integration_config $1 $2
  fi
  
  echo "Vault integration configuration completed successfully!"
}

# Execute main function
main "$@"
