# Vault Configuration for AWS CloudSec Microservices Platform

# UI configuration
ui = true

# API configuration
api_addr = "https://vault.cloudsec-platform.internal:8200"

# Listener configuration for HTTPS
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault/tls/vault.crt"
  tls_key_file = "/etc/vault/tls/vault.key"
}

# Storage backend configuration using AWS DynamoDB
storage "dynamodb" {
  ha_enabled = "true"
  region = "us-east-1"
  table = "vault-data"
}

# Auto-unseal using AWS KMS
seal "awskms" {
  region = "us-east-1"
  kms_key_id = "alias/vault-unseal-key"
}

# Telemetry configuration for monitoring
telemetry {
  statsite_address = "127.0.0.1:8125"
  disable_hostname = true
  prometheus_retention_time = "30s"
  usage_gauge_period = "10m"
}

# Enable audit logging to file
audit {
  type = "file"
  path = "/var/log/vault/audit.log"
}
