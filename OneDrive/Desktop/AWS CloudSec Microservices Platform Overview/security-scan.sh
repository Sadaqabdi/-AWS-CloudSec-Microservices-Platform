#!/bin/bash
# Security Vulnerability Scanning Script for AWS CloudSec Microservices Platform

echo "Starting security vulnerability scanning..."

# Create output directory
mkdir -p /home/ubuntu/aws-cloudsec-microservices/testing/security/reports

# Set output paths
REPORT_DIR="/home/ubuntu/aws-cloudsec-microservices/testing/security/reports"
SUMMARY_REPORT="$REPORT_DIR/security-summary-report.md"
DEPENDENCY_REPORT="$REPORT_DIR/dependency-vulnerabilities.json"
CODE_REPORT="$REPORT_DIR/code-vulnerabilities.json"
CONTAINER_REPORT="$REPORT_DIR/container-vulnerabilities.json"
IAC_REPORT="$REPORT_DIR/infrastructure-vulnerabilities.json"
SECRET_REPORT="$REPORT_DIR/secret-scan-results.json"

# Initialize summary report
cat > $SUMMARY_REPORT << EOF
# Security Vulnerability Scan Report

## AWS CloudSec Microservices Platform

Date: $(date)

## Summary

This report contains the results of automated security scanning performed on the AWS CloudSec Microservices Platform.

## Scan Types

1. Dependency Vulnerability Scanning
2. Static Code Analysis
3. Container Security Scanning
4. Infrastructure as Code Security Scanning
5. Secret Detection

## Results Overview

EOF

echo "Installing security scanning tools..."

# Install dependency scanning tools
npm install -g npm-audit-html snyk
pip install safety

# Install static code analysis tools
npm install -g eslint eslint-plugin-security
pip install bandit

# Install container scanning tools
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Install IaC scanning tools
pip install checkov

# Install secret detection tools
pip install detect-secrets

echo "Scanning dependencies for vulnerabilities..."

# Scan Node.js dependencies
echo "### Node.js Dependencies" >> $SUMMARY_REPORT
echo "" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices/microservices/authentication-service
echo "Scanning authentication service dependencies..."
npm audit --json > $REPORT_DIR/auth-npm-audit.json
VULN_COUNT=$(cat $REPORT_DIR/auth-npm-audit.json | grep -o '"vulnerabilities":{"total":[0-9]*' | grep -o '[0-9]*$')
echo "- Authentication Service: $VULN_COUNT vulnerabilities found" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices/microservices/business-service
echo "Scanning business service dependencies..."
npm audit --json > $REPORT_DIR/business-npm-audit.json
VULN_COUNT=$(cat $REPORT_DIR/business-npm-audit.json | grep -o '"vulnerabilities":{"total":[0-9]*' | grep -o '[0-9]*$')
echo "- Business Service: $VULN_COUNT vulnerabilities found" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices/microservices/frontend-service
echo "Scanning frontend service dependencies..."
npm audit --json > $REPORT_DIR/frontend-npm-audit.json
VULN_COUNT=$(cat $REPORT_DIR/frontend-npm-audit.json | grep -o '"vulnerabilities":{"total":[0-9]*' | grep -o '[0-9]*$')
echo "- Frontend Service: $VULN_COUNT vulnerabilities found" >> $SUMMARY_REPORT

echo "" >> $SUMMARY_REPORT

# Scan Python dependencies
echo "### Python Dependencies" >> $SUMMARY_REPORT
echo "" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices
echo "Scanning Python dependencies..."
safety check --json > $REPORT_DIR/python-safety-check.json
VULN_COUNT=$(cat $REPORT_DIR/python-safety-check.json | grep -o '"vulnerabilities_found": [0-9]*' | grep -o '[0-9]*$')
echo "- Python Dependencies: $VULN_COUNT vulnerabilities found" >> $SUMMARY_REPORT

echo "" >> $SUMMARY_REPORT

echo "Performing static code analysis..."

# Static code analysis
echo "## Static Code Analysis" >> $SUMMARY_REPORT
echo "" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices
echo "Scanning JavaScript code with ESLint..."
npx eslint --no-eslintrc -c '{"extends":["plugin:security/recommended"]}' --format json microservices/**/*.js > $REPORT_DIR/eslint-results.json 2>/dev/null || true
JS_ISSUES=$(cat $REPORT_DIR/eslint-results.json | grep -o '"errorCount":[0-9]*' | grep -o '[0-9]*' | awk '{s+=$1} END {print s}')
echo "- JavaScript Security Issues: $JS_ISSUES issues found" >> $SUMMARY_REPORT

echo "Scanning Python code with Bandit..."
bandit -r . -f json -o $REPORT_DIR/bandit-results.json || true
PY_ISSUES=$(cat $REPORT_DIR/bandit-results.json | grep -o '"issue_severity": "[^"]*"' | wc -l)
echo "- Python Security Issues: $PY_ISSUES issues found" >> $SUMMARY_REPORT

echo "" >> $SUMMARY_REPORT

echo "Scanning container images for vulnerabilities..."

# Container security scanning
echo "## Container Security" >> $SUMMARY_REPORT
echo "" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices
echo "Scanning Dockerfiles with Trivy..."
trivy config --format json --output $REPORT_DIR/dockerfile-scan.json docker/*.Dockerfile || true
CONTAINER_ISSUES=$(cat $REPORT_DIR/dockerfile-scan.json | grep -o '"Severity": "[^"]*"' | grep -i -e high -e critical | wc -l)
echo "- Dockerfile Security Issues: $CONTAINER_ISSUES high/critical issues found" >> $SUMMARY_REPORT

echo "" >> $SUMMARY_REPORT

echo "Scanning infrastructure as code for security issues..."

# Infrastructure as code scanning
echo "## Infrastructure as Code Security" >> $SUMMARY_REPORT
echo "" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices
echo "Scanning Terraform code with Checkov..."
checkov -d infrastructure --output json > $REPORT_DIR/checkov-results.json || true
IAC_ISSUES=$(cat $REPORT_DIR/checkov-results.json | grep -o '"check_result": "FAILED"' | wc -l)
echo "- Terraform Security Issues: $IAC_ISSUES issues found" >> $SUMMARY_REPORT

echo "" >> $SUMMARY_REPORT

echo "Scanning for hardcoded secrets..."

# Secret detection
echo "## Secret Detection" >> $SUMMARY_REPORT
echo "" >> $SUMMARY_REPORT

cd /home/ubuntu/aws-cloudsec-microservices
echo "Scanning for secrets with detect-secrets..."
detect-secrets scan --all-files > $REPORT_DIR/secrets-results.json || true
SECRET_COUNT=$(cat $REPORT_DIR/secrets-results.json | grep -o '"is_secret": true' | wc -l)
echo "- Potential Secrets Found: $SECRET_COUNT" >> $SUMMARY_REPORT

echo "" >> $SUMMARY_REPORT

# Add recommendations
cat >> $SUMMARY_REPORT << EOF
## Recommendations

Based on the scan results, the following security improvements are recommended:

1. Update dependencies with known vulnerabilities
2. Fix identified code security issues
3. Address container security concerns
4. Remediate infrastructure as code security issues
5. Remove any hardcoded secrets and store them in HashiCorp Vault

## Next Steps

1. Review detailed reports in the reports directory
2. Prioritize vulnerabilities based on severity
3. Create remediation plan for identified issues
4. Implement fixes and re-scan to verify remediation
5. Integrate security scanning into CI/CD pipeline
EOF

echo "Security vulnerability scanning completed. Reports available in $REPORT_DIR"
echo "Summary report: $SUMMARY_REPORT"
