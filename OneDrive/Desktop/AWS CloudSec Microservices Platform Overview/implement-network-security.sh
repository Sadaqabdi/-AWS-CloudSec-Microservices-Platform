#!/bin/bash

# AWS CloudSec Microservices Platform - Network Security Implementation Script
# This script implements additional network security measures for the AWS CloudSec Microservices Platform

echo "Starting network security implementation..."

# Create a directory for security scripts
mkdir -p /home/ubuntu/aws-cloudsec-microservices/security/scripts
cd /home/ubuntu/aws-cloudsec-microservices/security/scripts

# Create AWS WAF configuration
cat > waf-config.json << 'EOF'
{
  "Name": "cloudsec-waf-web-acl",
  "Scope": "REGIONAL",
  "DefaultAction": {
    "Allow": {}
  },
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "cloudsec-waf-web-acl"
  },
  "Rules": [
    {
      "Name": "AWS-AWSManagedRulesCommonRuleSet",
      "Priority": 0,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWS-AWSManagedRulesCommonRuleSet"
      }
    },
    {
      "Name": "AWS-AWSManagedRulesSQLiRuleSet",
      "Priority": 1,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesSQLiRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWS-AWSManagedRulesSQLiRuleSet"
      }
    },
    {
      "Name": "AWS-AWSManagedRulesKnownBadInputsRuleSet",
      "Priority": 2,
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesKnownBadInputsRuleSet"
        }
      },
      "OverrideAction": {
        "None": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      }
    },
    {
      "Name": "RateBasedRule",
      "Priority": 3,
      "Statement": {
        "RateBasedStatement": {
          "Limit": 1000,
          "AggregateKeyType": "IP"
        }
      },
      "Action": {
        "Block": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateBasedRule"
      }
    }
  ]
}
EOF

# Create AWS Shield Advanced configuration
cat > shield-config.json << 'EOF'
{
  "Name": "cloudsec-shield-protection",
  "ResourceArns": [
    "arn:aws:elasticloadbalancing:REGION:ACCOUNT_ID:loadbalancer/app/cloudsec-alb/LOAD_BALANCER_ID"
  ],
  "EnabledAutomaticResponseActions": [
    "COUNT",
    "BLOCK"
  ],
  "ResponseAction": {
    "Block": {}
  }
}
EOF

# Create AWS GuardDuty configuration
cat > guardduty-config.json << 'EOF'
{
  "Enable": true,
  "FindingPublishingFrequency": "FIFTEEN_MINUTES",
  "DataSources": {
    "S3Logs": {
      "Enable": true
    },
    "Kubernetes": {
      "AuditLogs": {
        "Enable": true
      }
    },
    "MalwareProtection": {
      "ScanEc2InstanceWithFindings": {
        "EbsVolumes": {
          "Enable": true
        }
      }
    }
  }
}
EOF

# Create AWS Config rules for network security
cat > config-rules.json << 'EOF'
[
  {
    "ConfigRuleName": "vpc-flow-logs-enabled",
    "Description": "Checks whether Amazon Virtual Private Cloud flow logs are found and enabled for Amazon VPC.",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "VPC_FLOW_LOGS_ENABLED"
    },
    "Scope": {
      "ComplianceResourceTypes": [
        "AWS::EC2::VPC"
      ]
    }
  },
  {
    "ConfigRuleName": "restricted-ssh",
    "Description": "Checks whether security groups that are in use disallow unrestricted incoming SSH traffic.",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "INCOMING_SSH_DISABLED"
    },
    "Scope": {
      "ComplianceResourceTypes": [
        "AWS::EC2::SecurityGroup"
      ]
    }
  },
  {
    "ConfigRuleName": "restricted-common-ports",
    "Description": "Checks whether security groups that are in use disallow unrestricted incoming TCP traffic to the specified ports.",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "RESTRICTED_INCOMING_TRAFFIC"
    },
    "InputParameters": {
      "blockedPort1": "22",
      "blockedPort2": "3389",
      "blockedPort3": "3306",
      "blockedPort4": "5432",
      "blockedPort5": "6379"
    },
    "Scope": {
      "ComplianceResourceTypes": [
        "AWS::EC2::SecurityGroup"
      ]
    }
  },
  {
    "ConfigRuleName": "vpc-sg-open-only-to-authorized-ports",
    "Description": "Checks whether any security groups with inbound 0.0.0.0/0 have TCP or UDP ports accessible.",
    "Source": {
      "Owner": "AWS",
      "SourceIdentifier": "VPC_SG_OPEN_ONLY_TO_AUTHORIZED_PORTS"
    },
    "InputParameters": {
      "authorizedTcpPorts": "80,443"
    },
    "Scope": {
      "ComplianceResourceTypes": [
        "AWS::EC2::SecurityGroup"
      ]
    }
  }
]
EOF

# Create VPC Flow Logs analysis script
cat > analyze-vpc-flow-logs.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import datetime
import argparse

def analyze_flow_logs(log_group_name, hours=24):
    """
    Analyze VPC Flow Logs to detect suspicious patterns
    """
    client = boto3.client('logs')
    
    # Calculate time range
    end_time = datetime.datetime.now()
    start_time = end_time - datetime.timedelta(hours=hours)
    
    # Convert to milliseconds since epoch
    start_time_ms = int(start_time.timestamp() * 1000)
    end_time_ms = int(end_time.timestamp() * 1000)
    
    print(f"Analyzing VPC Flow Logs from {start_time} to {end_time}")
    
    # Patterns to look for
    patterns = [
        # Rejected connections
        "{ $.action = \"REJECT\" }",
        # SSH attempts from outside the VPC
        "{ $.dstPort = 22 && $.action = \"REJECT\" }",
        # Database port access attempts from outside the VPC
        "{ $.dstPort = 3306 && $.action = \"REJECT\" }",
        "{ $.dstPort = 5432 && $.action = \"REJECT\" }",
        # Unusual high volume traffic
        "{ $.bytes > 1000000 }"
    ]
    
    for pattern in patterns:
        print(f"\nSearching for pattern: {pattern}")
        
        try:
            response = client.start_query(
                logGroupName=log_group_name,
                startTime=start_time_ms,
                endTime=end_time_ms,
                queryString=f"fields @timestamp, srcAddr, dstAddr, srcPort, dstPort, action, bytes | filter {pattern} | sort @timestamp desc | limit 20"
            )
            
            query_id = response['queryId']
            
            # Wait for query to complete
            response = client.get_query_results(queryId=query_id)
            while response['status'] == 'Running':
                print("Query still running...")
                time.sleep(1)
                response = client.get_query_results(queryId=query_id)
            
            # Process results
            if response['results']:
                print(f"Found {len(response['results'])} matching events:")
                for result in response['results']:
                    event = {item['field']: item['value'] for item in result}
                    print(json.dumps(event, indent=2))
            else:
                print("No matching events found.")
                
        except Exception as e:
            print(f"Error analyzing logs: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Analyze VPC Flow Logs for security issues')
    parser.add_argument('--log-group', required=True, help='CloudWatch Log Group name for VPC Flow Logs')
    parser.add_argument('--hours', type=int, default=24, help='Number of hours to analyze (default: 24)')
    
    args = parser.parse_args()
    analyze_flow_logs(args.log_group, args.hours)
EOF

chmod +x analyze-vpc-flow-logs.py

# Create security group audit script
cat > audit-security-groups.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import argparse
import csv
from datetime import datetime

def audit_security_groups(vpc_id=None, output_format='json'):
    """
    Audit security groups for potential security issues
    """
    ec2 = boto3.client('ec2')
    
    # Get all security groups, optionally filtered by VPC
    filters = []
    if vpc_id:
        filters.append({
            'Name': 'vpc-id',
            'Values': [vpc_id]
        })
    
    response = ec2.describe_security_groups(Filters=filters)
    security_groups = response['SecurityGroups']
    
    print(f"Auditing {len(security_groups)} security groups...")
    
    issues = []
    
    for sg in security_groups:
        sg_id = sg['GroupId']
        sg_name = sg['GroupName']
        
        # Check for overly permissive inbound rules
        for rule in sg.get('IpPermissions', []):
            for ip_range in rule.get('IpRanges', []):
                cidr = ip_range.get('CidrIp', '')
                
                # Check for 0.0.0.0/0 (open to the world)
                if cidr == '0.0.0.0/0':
                    from_port = rule.get('FromPort', 0)
                    to_port = rule.get('ToPort', 0)
                    protocol = rule.get('IpProtocol', '-1')
                    
                    # If protocol is -1, it means all protocols
                    if protocol == '-1':
                        protocol_desc = 'All Protocols'
                        port_desc = 'All Ports'
                    else:
                        protocol_desc = protocol
                        if from_port == to_port:
                            port_desc = str(from_port)
                        else:
                            port_desc = f"{from_port}-{to_port}"
                    
                    # Determine severity
                    severity = 'INFO'
                    if protocol == '-1':
                        severity = 'HIGH'
                    elif from_port <= 22 <= to_port and protocol in ['tcp', '6']:
                        severity = 'HIGH'  # SSH open to the world
                    elif (from_port <= 3389 <= to_port and protocol in ['tcp', '6']):
                        severity = 'HIGH'  # RDP open to the world
                    elif (from_port <= 3306 <= to_port or from_port <= 5432 <= to_port) and protocol in ['tcp', '6']:
                        severity = 'HIGH'  # Database ports open to the world
                    elif from_port <= 80 <= to_port and protocol in ['tcp', '6']:
                        severity = 'MEDIUM'  # HTTP open to the world
                    elif from_port <= 443 <= to_port and protocol in ['tcp', '6']:
                        severity = 'LOW'  # HTTPS open to the world
                    
                    issues.append({
                        'sg_id': sg_id,
                        'sg_name': sg_name,
                        'issue_type': 'Open to World',
                        'protocol': protocol_desc,
                        'ports': port_desc,
                        'cidr': cidr,
                        'severity': severity,
                        'description': f"Security group allows {protocol_desc} traffic on port(s) {port_desc} from any IP address"
                    })
    
    # Output results
    if output_format == 'json':
        print(json.dumps(issues, indent=2))
    elif output_format == 'csv':
        timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
        filename = f"security-group-audit-{timestamp}.csv"
        with open(filename, 'w', newline='') as csvfile:
            fieldnames = ['sg_id', 'sg_name', 'issue_type', 'protocol', 'ports', 'cidr', 'severity', 'description']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            for issue in issues:
                writer.writerow(issue)
        print(f"Results written to {filename}")
    
    # Summary
    high = sum(1 for i in issues if i['severity'] == 'HIGH')
    medium = sum(1 for i in issues if i['severity'] == 'MEDIUM')
    low = sum(1 for i in issues if i['severity'] == 'LOW')
    info = sum(1 for i in issues if i['severity'] == 'INFO')
    
    print(f"\nSecurity Group Audit Summary:")
    print(f"HIGH severity issues: {high}")
    print(f"MEDIUM severity issues: {medium}")
    print(f"LOW severity issues: {low}")
    print(f"INFO severity issues: {info}")
    
    return issues

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Audit AWS Security Groups for security issues')
    parser.add_argument('--vpc-id', help='VPC ID to filter security groups')
    parser.add_argument('--format', choices=['json', 'csv'], default='json', help='Output format (default: json)')
    
    args = parser.parse_args()
    audit_security_groups(args.vpc_id, args.format)
EOF

chmod +x audit-security-groups.py

# Create network ACL audit script
cat > audit-network-acls.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import argparse
import csv
from datetime import datetime

def audit_network_acls(vpc_id=None, output_format='json'):
    """
    Audit Network ACLs for potential security issues
    """
    ec2 = boto3.client('ec2')
    
    # Get all Network ACLs, optionally filtered by VPC
    filters = []
    if vpc_id:
        filters.append({
            'Name': 'vpc-id',
            'Values': [vpc_id]
        })
    
    response = ec2.describe_network_acls(Filters=filters)
    network_acls = response['NetworkAcls']
    
    print(f"Auditing {len(network_acls)} Network ACLs...")
    
    issues = []
    
    for acl in network_acls:
        acl_id = acl['NetworkAclId']
        is_default = acl.get('IsDefault', False)
        
        # Get associated subnets
        subnet_ids = [assoc['SubnetId'] for assoc in acl.get('Associations', [])]
        subnet_str = ', '.join(subnet_ids) if subnet_ids else 'None'
        
        # Check inbound rules
        for entry in acl.get('Entries', []):
            if not entry.get('Egress', False):  # Inbound rule
                rule_number = entry.get('RuleNumber', 0)
                cidr = entry.get('CidrBlock', '')
                protocol = entry.get('Protocol', '-1')
                rule_action = entry.get('RuleAction', '')
                
                # Skip the default deny rule (usually rule number 32767)
                if rule_number == 32767:
                    continue
                
                # Check for overly permissive rules
                if cidr == '0.0.0.0/0' and rule_action == 'allow':
                    port_range_from = entry.get('PortRange', {}).get('From', 0)
                    port_range_to = entry.get('PortRange', {}).get('To', 65535)
                    
                    # Determine protocol description
                    if protocol == '-1':
                        protocol_desc = 'All Protocols'
                    elif protocol == '6':
                        protocol_desc = 'TCP'
                    elif protocol == '17':
                        protocol_desc = 'UDP'
                    elif protocol == '1':
                        protocol_desc = 'ICMP'
                    else:
                        protocol_desc = protocol
                    
                    # Determine port description
                    if port_range_from == 0 and port_range_to == 65535:
                        port_desc = 'All Ports'
                    elif port_range_from == port_range_to:
                        port_desc = str(port_range_from)
                    else:
                        port_desc = f"{port_range_from}-{port_range_to}"
                    
                    # Determine severity
                    severity = 'INFO'
                    if protoco
(Content truncated due to size limit. Use line ranges to read in chunks)