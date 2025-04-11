# AWS CloudSec Microservices Platform - Deployment Guide

This guide provides step-by-step instructions for deploying the AWS CloudSec Microservices Platform. It covers infrastructure provisioning, microservices deployment, and post-deployment verification.

## Prerequisites

Before beginning the deployment, ensure you have the following:

- AWS Account with administrative permissions
- AWS CLI configured with appropriate credentials
- Terraform v1.0.0 or later
- kubectl v1.21.0 or later
- Docker v20.10.0 or later
- Helm v3.6.0 or later
- Git client

## Deployment Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-organization/aws-cloudsec-microservices.git
cd aws-cloudsec-microservices
```

### 2. Configure Deployment Parameters

Create a `terraform.tfvars` file in the infrastructure directory:

```bash
cd infrastructure
cat > terraform.tfvars << EOF
# AWS Configuration
aws_region = "us-east-1"
environment = "prod"
vpc_cidr = "10.0.0.0/16"

# EKS Configuration
eks_cluster_name = "cloudsec-eks-cluster"
eks_cluster_version = "1.21"
eks_node_group_instance_types = ["t3.large"]
eks_node_group_desired_capacity = 3
eks_node_group_min_size = 2
eks_node_group_max_size = 5

# Database Configuration
rds_instance_class = "db.t3.medium"
rds_allocated_storage = 20
rds_engine_version = "13.4"

# ElastiCache Configuration
elasticache_node_type = "cache.t3.medium"
elasticache_num_cache_nodes = 2

# DynamoDB Configuration
dynamodb_billing_mode = "PAY_PER_REQUEST"

# S3 Configuration
s3_frontend_bucket_name = "cloudsec-frontend-${random_string.suffix.result}"

# Cognito Configuration
cognito_user_pool_name = "cloudsec-user-pool"
EOF
```

### 3. Deploy Infrastructure with Terraform

Initialize and apply the Terraform configuration:

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This will provision the following AWS resources:
- VPC with public and private subnets
- EKS cluster
- RDS PostgreSQL database
- DynamoDB tables
- ElastiCache Redis cluster
- S3 bucket for frontend
- Cognito user pool
- IAM roles and policies
- Security groups
- KMS keys

### 4. Configure kubectl for EKS

Update your kubeconfig to connect to the EKS cluster:

```bash
aws eks update-kubeconfig --name cloudsec-eks-cluster --region us-east-1
kubectl get nodes # Verify connectivity
```

### 5. Deploy HashiCorp Vault

Deploy Vault using Helm:

```bash
cd ../vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
  -f vault/helm-values.yaml \
  --namespace vault \
  --create-namespace
```

Initialize and unseal Vault:

```bash
kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=5 -key-threshold=3
# Save the unseal keys and root token securely

# Unseal Vault (repeat with 3 different unseal keys)
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-1>
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-2>
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-3>
```

Configure Vault:

```bash
# Log in to Vault
kubectl exec -it vault-0 -n vault -- vault login

# Run the initialization script
kubectl cp vault/scripts/initialize-vault.sh vault-0:/tmp/ -n vault
kubectl exec -it vault-0 -n vault -- sh /tmp/initialize-vault.sh
```

### 6. Build and Push Docker Images

Build and push the Docker images for each microservice:

```bash
cd ../

# Set up environment variables
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export ECR_REPO_PREFIX=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Log in to ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO_PREFIX}

# Create ECR repositories if they don't exist
for service in authentication-service business-service frontend-service; do
  aws ecr create-repository --repository-name cloudsec/${service} --region ${AWS_REGION} || true
done

# Build and push images
for service in authentication-service business-service frontend-service; do
  docker build -t ${ECR_REPO_PREFIX}/cloudsec/${service}:latest -f docker/${service}.Dockerfile microservices/${service}
  docker push ${ECR_REPO_PREFIX}/cloudsec/${service}:latest
done
```

### 7. Deploy Kubernetes Resources

Deploy the Kubernetes resources:

```bash
cd kubernetes

# Update image references in the deployment files
for file in base/*-deployment.yaml; do
  sed -i "s|\${AWS_ACCOUNT_ID}|${AWS_ACCOUNT_ID}|g" $file
  sed -i "s|\${AWS_REGION}|${AWS_REGION}|g" $file
done

# Create namespace
kubectl create namespace cloudsec

# Apply Kubernetes manifests
kubectl apply -k overlays/prod/
```

### 8. Configure DNS and SSL

If you're using a custom domain:

```bash
# Get the ALB DNS name
export ALB_DNS=$(kubectl get ingress -n cloudsec main-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route 53 record (replace with your domain and hosted zone ID)
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "app.yourdomain.com",
          "Type": "CNAME",
          "TTL": 300,
          "ResourceRecords": [
            {
              "Value": "'$ALB_DNS'"
            }
          ]
        }
      }
    ]
  }'
```

### 9. Deploy Monitoring Stack

Deploy Prometheus and Grafana:

```bash
cd ../monitoring

# Create namespace
kubectl create namespace monitoring

# Deploy Prometheus
kubectl apply -f prometheus/prometheus-config.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml

# Deploy Grafana
kubectl apply -f grafana/grafana-config.yaml
kubectl create secret generic grafana-admin-credentials \
  --from-literal=username=admin \
  --from-literal=password=$(openssl rand -base64 12) \
  -n monitoring

# Get Grafana admin password
kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath="{.data.password}" | base64 --decode
```

### 10. Configure CI/CD Pipeline

Deploy the CI/CD pipeline using CloudFormation:

```bash
cd ../cicd

# Create S3 bucket for CloudFormation template
aws s3 mb s3://cloudsec-cfn-templates-${AWS_ACCOUNT_ID}

# Package and deploy CloudFormation template
aws cloudformation package \
  --template-file pipeline.yaml \
  --s3-bucket cloudsec-cfn-templates-${AWS_ACCOUNT_ID} \
  --output-template-file pipeline-packaged.yaml

aws cloudformation deploy \
  --template-file pipeline-packaged.yaml \
  --stack-name cloudsec-cicd-pipeline \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    GitHubOwner=your-organization \
    GitHubRepo=aws-cloudsec-microservices \
    GitHubBranch=main \
    GitHubToken=your-github-token
```

### 11. Post-Deployment Verification

Verify the deployment:

```bash
# Check EKS pods
kubectl get pods -n cloudsec

# Check services
kubectl get services -n cloudsec

# Check ingress
kubectl get ingress -n cloudsec

# Check Vault status
kubectl exec -it vault-0 -n vault -- vault status

# Check Prometheus and Grafana
kubectl get pods -n monitoring
```

## Accessing the Application

- **Frontend**: https://app.yourdomain.com or the ALB DNS name
- **API Gateway**: https://api.yourdomain.com or the API Gateway endpoint
- **Grafana**: https://grafana.yourdomain.com or the Grafana service endpoint

## Troubleshooting

### Common Issues

#### EKS Pod Startup Failures

If pods are not starting:

```bash
kubectl describe pod <pod-name> -n cloudsec
kubectl logs <pod-name> -n cloudsec
```

Check for:
- Image pull errors
- Resource constraints
- Configuration errors
- Volume mount issues

#### Database Connection Issues

If services can't connect to the database:

```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier cloudsec-db

# Check security group rules
aws ec2 describe-security-groups --group-ids <rds-security-group-id>

# Test connectivity from a pod
kubectl exec -it <pod-name> -n cloudsec -- nc -zv <rds-endpoint> 5432
```

#### Vault Integration Issues

If services can't access secrets:

```bash
# Check Vault status
kubectl exec -it vault-0 -n vault -- vault status

# Check Vault agent logs
kubectl logs <pod-name> -c vault-agent -n cloudsec

# Verify Vault policies
kubectl exec -it vault-0 -n vault -- vault policy read <policy-name>
```

## Rollback Procedures

### Infrastructure Rollback

To roll back the infrastructure:

```bash
cd infrastructure
terraform destroy
```

### Kubernetes Deployment Rollback

To roll back a specific deployment:

```bash
kubectl rollout undo deployment/<deployment-name> -n cloudsec
```

To roll back to a specific revision:

```bash
kubectl rollout history deployment/<deployment-name> -n cloudsec
kubectl rollout undo deployment/<deployment-name> --to-revision=<revision-number> -n cloudsec
```

## Security Considerations

- Store Vault unseal keys and root token securely
- Rotate AWS access keys regularly
- Enable AWS CloudTrail for auditing
- Implement AWS Config rules for compliance
- Use AWS GuardDuty for threat detection
- Regularly scan for vulnerabilities using the provided security scripts

## Next Steps

After deployment:

1. Run security scans:
   ```bash
   cd testing/security
   ./security-scan.sh
   ```

2. Run load tests:
   ```bash
   cd testing/load
   ./load-test.sh
   ```

3. Set up regular backups and test restore procedures
4. Implement monitoring alerts
5. Document any environment-specific configurations

## Appendix

### Environment Variables

The following environment variables are used by the microservices:

#### Authentication Service
- `AUTH_PORT`: Port for the authentication service (default: 3000)
- `COGNITO_USER_POOL_ID`: AWS Cognito user pool ID
- `COGNITO_CLIENT_ID`: AWS Cognito client ID
- `JWT_SECRET`: Secret for JWT signing
- `VAULT_ADDR`: HashiCorp Vault address

#### Business Service
- `API_PORT`: Port for the business service (default: 3001)
- `DYNAMODB_TABLE`: DynamoDB table name
- `AUTH_SERVICE_URL`: URL of the authentication service
- `VAULT_ADDR`: HashiCorp Vault address

#### Frontend Service
- `NEXT_PUBLIC_API_URL`: URL of the API Gateway
- `NEXT_PUBLIC_AUTH_URL`: URL of the authentication service

### Resource Sizing

| Component | Development | Staging | Production |
|-----------|-------------|---------|------------|
| EKS Nodes | 2 x t3.medium | 2 x t3.large | 3+ x t3.large |
| RDS | db.t3.small | db.t3.medium | db.t3.large |
| ElastiCache | cache.t3.small | cache.t3.medium | cache.t3.medium |
| DynamoDB | On-demand | On-demand | On-demand |

### AWS Service Limits

Ensure the following AWS service limits are sufficient:

- VPCs per region: At least 1
- Subnets per VPC: At least 6
- Internet Gateways per region: At least 1
- NAT Gateways per AZ: At least 1
- EKS clusters per region: At least 1
- EC2 instances per region: At least 5
- RDS instances per region: At least 1
- ElastiCache clusters per region: At least 1
- S3 buckets per account: At least 5
- DynamoDB tables per region: At least 3
- CloudWatch Log Groups per region: At least 10
