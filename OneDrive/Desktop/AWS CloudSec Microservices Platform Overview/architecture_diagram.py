#!/usr/bin/env python3
from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EKS, Lambda, EC2
from diagrams.aws.database import RDS, ElastiCache, Dynamodb
from diagrams.aws.network import ELB, VPC, APIGateway, CloudFront, Route53
from diagrams.aws.security import IAM, Cognito, WAF, Shield, ACM, KMS
from diagrams.aws.storage import S3
from diagrams.aws.integration import SNS, Eventbridge
from diagrams.aws.management import Cloudwatch, Cloudformation
from diagrams.aws.devtools import Codebuild, Codepipeline, Codedeploy
from diagrams.onprem.vcs import Github
from diagrams.onprem.container import Docker
from diagrams.onprem.security import Vault
from diagrams.onprem.monitoring import Prometheus, Grafana
from diagrams.onprem.network import Nginx
from diagrams.programming.framework import React
from diagrams.programming.language import NodeJS, Python

# Set graph attributes
graph_attr = {
    "fontsize": "24",
    "bgcolor": "white",
    "splines": "spline",
    "pad": "0.5",
    "nodesep": "0.60",
    "ranksep": "0.75",
    "fontname": "Sans-Serif",
    "fontcolor": "#2D3436",
    "fontsize": "24",
    "labelloc": "t",
}

# Create the main diagram
with Diagram("AWS CloudSec Microservices Platform", show=False, filename="aws-cloudsec-architecture", outformat="png", graph_attr=graph_attr, direction="TB"):
    
    # External clients
    with Cluster("Clients"):
        clients = [
            React("Web Client"),
            Nginx("Mobile Client"),
            EC2("API Client")
        ]
    
    # Edge Services
    with Cluster("Edge Layer"):
        route53 = Route53("Route 53")
        cloudfront = CloudFront("CloudFront")
        waf = WAF("WAF")
        shield = Shield("Shield")
    
    # API Gateway
    api = APIGateway("API Gateway")
    
    # Network Layer
    with Cluster("Network Layer"):
        with Cluster("VPC"):
            vpc = VPC("VPC")
            
            with Cluster("Public Subnet"):
                public_subnet = [
                    ELB("Load Balancer")
                ]
            
            with Cluster("Private Subnet - App Tier"):
                with Cluster("EKS Cluster"):
                    eks = EKS("Kubernetes")
                    
                    with Cluster("Microservices"):
                        auth_service = Cognito("Auth Service")
                        business_service = [
                            NodeJS("Business Service 1"),
                            Python("Business Service 2")
                        ]
                        frontend = S3("Frontend Assets")
            
            with Cluster("Private Subnet - Data Tier"):
                rds = RDS("RDS Database")
                dynamodb = Dynamodb("DynamoDB")
                elasticache = ElastiCache("ElastiCache")
    
    # Security Services
    with Cluster("Security Layer"):
        iam = IAM("IAM")
        kms = KMS("KMS")
        acm = ACM("Certificate Manager")
        vault = Vault("HashiCorp Vault")
    
    # DevOps & CI/CD
    with Cluster("DevOps Layer"):
        github = Github("Source Code")
        with Cluster("CI/CD Pipeline"):
            codepipeline = Codepipeline("CodePipeline")
            codebuild = Codebuild("CodeBuild")
            codedeploy = Codedeploy("CodeDeploy")
        docker = Docker("Container Registry")
        cloudformation = Cloudformation("Terraform/CloudFormation")
    
    # Monitoring & Observability
    with Cluster("Monitoring Layer"):
        cloudwatch = Cloudwatch("CloudWatch")
        prometheus = Prometheus("Prometheus")
        grafana = Grafana("Grafana")
        sns = SNS("SNS")
        eventbridge = Eventbridge("EventBridge")
        lambda_fn = Lambda("Lambda Functions")
    
    # Define the connections
    clients >> route53 >> cloudfront >> waf >> api
    shield - Edge(color="red", style="dashed") - cloudfront
    
    api >> public_subnet >> eks
    
    eks >> auth_service
    eks >> business_service
    eks >> frontend
    
    auth_service >> iam
    auth_service >> vault
    business_service >> rds
    business_service >> dynamodb
    business_service >> elasticache
    business_service >> vault
    
    github >> codepipeline >> codebuild >> codedeploy >> eks
    codebuild >> docker >> eks
    cloudformation >> vpc
    
    eks >> cloudwatch
    eks >> prometheus >> grafana
    cloudwatch >> sns >> lambda_fn
    cloudwatch >> eventbridge >> lambda_fn
    
    kms - Edge(color="green", style="dashed") - [rds, dynamodb, elasticache]
    acm - Edge(color="green", style="dashed") - [api, cloudfront]
