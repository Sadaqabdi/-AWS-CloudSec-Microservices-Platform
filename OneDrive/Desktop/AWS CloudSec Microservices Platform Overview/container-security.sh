#!/bin/bash
# Script to implement container security best practices

# Set up container scanning with Trivy
setup_trivy() {
  echo "Setting up Trivy container scanner..."
  
  # Install Trivy
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
  echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
  sudo apt-get update
  sudo apt-get install -y trivy
  
  echo "Trivy installed successfully!"
}

# Scan a Docker image for vulnerabilities
scan_image() {
  local image=$1
  echo "Scanning Docker image: $image"
  
  trivy image $image
}

# Create .dockerignore file
create_dockerignore() {
  local service_dir=$1
  echo "Creating .dockerignore for $service_dir"
  
  cat > $service_dir/.dockerignore << EOF
# Version control
.git
.gitignore

# Node.js
node_modules
npm-debug.log

# Testing
coverage
.nyc_output
tests

# Environment variables
.env
.env.*

# Development files
*.md
*.log
.editorconfig
.eslintrc
.prettierrc

# Docker
Dockerfile
docker-compose.yml
.dockerignore

# Vault
vault/token/*
vault/secrets/*

# Misc
.DS_Store
.vscode
EOF

  echo ".dockerignore created for $service_dir"
}

# Apply security hardening to Dockerfiles
harden_dockerfile() {
  local dockerfile=$1
  echo "Applying security hardening to $dockerfile"
  
  # Add security labels
  sed -i '/^FROM/a LABEL org.opencontainers.image.vendor="AWS CloudSec Platform" \\' $dockerfile
  sed -i '/^LABEL/a \    org.opencontainers.image.title="Secure Microservice" \\' $dockerfile
  sed -i '/^LABEL/a \    org.opencontainers.image.description="Secure container for AWS CloudSec Platform" \\' $dockerfile
  sed -i '/^LABEL/a \    org.opencontainers.image.source="https://github.com/example/aws-cloudsec-microservices"' $dockerfile
  
  # Add health check if not present
  if ! grep -q "HEALTHCHECK" $dockerfile; then
    if [[ $dockerfile == *"authentication-service"* ]]; then
      sed -i '/^EXPOSE/a HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1' $dockerfile
    elif [[ $dockerfile == *"business-service"* ]]; then
      sed -i '/^EXPOSE/a HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1' $dockerfile
    elif [[ $dockerfile == *"frontend-service"* ]]; then
      sed -i '/^EXPOSE/a HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1' $dockerfile
    fi
  fi
  
  echo "Security hardening applied to $dockerfile"
}

# Main execution
main() {
  echo "Implementing container security best practices..."
  
  # Setup Trivy scanner
  setup_trivy
  
  # Create .dockerignore files
  create_dockerignore "/home/ubuntu/aws-cloudsec-microservices/microservices/authentication-service"
  create_dockerignore "/home/ubuntu/aws-cloudsec-microservices/microservices/business-service"
  create_dockerignore "/home/ubuntu/aws-cloudsec-microservices/microservices/frontend-service"
  
  # Harden Dockerfiles
  harden_dockerfile "/home/ubuntu/aws-cloudsec-microservices/docker/authentication-service.Dockerfile"
  harden_dockerfile "/home/ubuntu/aws-cloudsec-microservices/docker/business-service.Dockerfile"
  harden_dockerfile "/home/ubuntu/aws-cloudsec-microservices/docker/frontend-service.Dockerfile"
  
  echo "Container security best practices implemented successfully!"
}

# Execute main function
main
