#!/bin/bash
# Load Testing Script for AWS CloudSec Microservices Platform

echo "Starting load testing for AWS CloudSec Microservices Platform..."

# Create output directory
mkdir -p /home/ubuntu/aws-cloudsec-microservices/testing/load/reports

# Set output paths
REPORT_DIR="/home/ubuntu/aws-cloudsec-microservices/testing/load/reports"
SUMMARY_REPORT="$REPORT_DIR/load-test-summary.md"

# Initialize summary report
cat > $SUMMARY_REPORT << EOF
# Load Test Report

## AWS CloudSec Microservices Platform

Date: $(date)

## Summary

This report contains the results of load testing performed on the AWS CloudSec Microservices Platform.

## Test Scenarios

1. Authentication Service Load Test
2. Business Service Load Test
3. Frontend Service Load Test
4. End-to-End Flow Load Test

## Test Configuration

- **Tool**: k6 (https://k6.io/)
- **Virtual Users**: Varied by test
- **Duration**: Varied by test
- **Ramp-up Period**: 30 seconds
- **Steady State**: 2-5 minutes
- **Ramp-down Period**: 30 seconds

## Results Overview

EOF

echo "Installing load testing tools..."

# Install k6 load testing tool
sudo apt-get update
sudo apt-get install -y ca-certificates gnupg2 apt-transport-https
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install -y k6

echo "Creating load test scripts..."

# Create authentication service load test script
cat > /home/ubuntu/aws-cloudsec-microservices/testing/load/auth-service-test.js << EOF
import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// Custom metrics
const loginSuccessRate = new Rate('login_success_rate');
const registerSuccessRate = new Rate('register_success_rate');
const authLatency = new Trend('auth_latency');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 50 },  // Ramp-up to 50 users
    { duration: '2m', target: 50 },   // Stay at 50 users for 2 minutes
    { duration: '30s', target: 0 },   // Ramp-down to 0 users
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500'],  // 95% of requests should be below 500ms
    'login_success_rate': ['rate>0.95'],  // 95% of logins should succeed
    'register_success_rate': ['rate>0.95'],  // 95% of registrations should succeed
  },
};

// Shared variables
const BASE_URL = 'http://localhost:3000';
let authToken = null;

// Helper function to generate random user data
function generateRandomUser() {
  const username = \`user_\${randomString(8)}\`;
  return {
    username: username,
    email: \`\${username}@example.com\`,
    password: \`Password\${randomString(4)}!\`
  };
}

// Main test function
export default function() {
  const userData = generateRandomUser();
  
  // Register a new user
  const registerStartTime = new Date();
  const registerRes = http.post(\`\${BASE_URL}/auth/register\`, JSON.stringify(userData), {
    headers: { 'Content-Type': 'application/json' },
  });
  authLatency.add(new Date() - registerStartTime);
  
  check(registerRes, {
    'register status is 201': (r) => r.status === 201,
    'register has userId': (r) => r.json('userId') !== undefined,
  }) ? registerSuccessRate.add(1) : registerSuccessRate.add(0);
  
  sleep(1);
  
  // Login with the registered user
  const loginStartTime = new Date();
  const loginRes = http.post(\`\${BASE_URL}/auth/login\`, JSON.stringify({
    username: userData.username,
    password: userData.password
  }), {
    headers: { 'Content-Type': 'application/json' },
  });
  authLatency.add(new Date() - loginStartTime);
  
  check(loginRes, {
    'login status is 200': (r) => r.status === 200,
    'login returns token': (r) => r.json('token') !== undefined,
  }) ? loginSuccessRate.add(1) : loginSuccessRate.add(0);
  
  if (loginRes.status === 200) {
    authToken = loginRes.json('token');
    
    // Verify token
    const verifyRes = http.get(\`\${BASE_URL}/auth/verify\`, {
      headers: { 
        'Authorization': \`Bearer \${authToken}\`,
        'Content-Type': 'application/json'
      },
    });
    
    check(verifyRes, {
      'verify status is 200': (r) => r.status === 200,
      'token is valid': (r) => r.json('valid') === true,
    });
  }
  
  sleep(2);
}
EOF

# Create business service load test script
cat > /home/ubuntu/aws-cloudsec-microservices/testing/load/business-service-test.js << EOF
import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// Custom metrics
const createItemSuccessRate = new Rate('create_item_success_rate');
const getItemSuccessRate = new Rate('get_item_success_rate');
const updateItemSuccessRate = new Rate('update_item_success_rate');
const deleteItemSuccessRate = new Rate('delete_item_success_rate');
const businessLatency = new Trend('business_latency');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 30 },  // Ramp-up to 30 users
    { duration: '3m', target: 30 },   // Stay at 30 users for 3 minutes
    { duration: '30s', target: 0 },   // Ramp-down to 0 users
  ],
  thresholds: {
    'http_req_duration': ['p(95)<600'],  // 95% of requests should be below 600ms
    'create_item_success_rate': ['rate>0.95'],  // 95% of item creations should succeed
    'get_item_success_rate': ['rate>0.95'],     // 95% of item retrievals should succeed
  },
};

// Shared variables
const BASE_URL = 'http://localhost:3001';
const AUTH_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItaWQiLCJ1c2VybmFtZSI6InRlc3R1c2VyIiwiaWF0IjoxNjE3MjkwNjQ1LCJleHAiOjE2MTczNzcwNDV9.test-token-signature';
let createdItemIds = [];

// Helper function to generate random item data
function generateRandomItem() {
  return {
    name: \`Item \${randomString(8)}\`,
    description: \`Description for item \${randomString(12)}\`,
    category: \`category-\${Math.floor(Math.random() * 5) + 1}\`,
    price: parseFloat((Math.random() * 100 + 10).toFixed(2))
  };
}

// Main test function
export default function() {
  // Create a new item
  const itemData = generateRandomItem();
  
  const createStartTime = new Date();
  const createRes = http.post(\`\${BASE_URL}/api/items\`, JSON.stringify(itemData), {
    headers: { 
      'Authorization': \`Bearer \${AUTH_TOKEN}\`,
      'Content-Type': 'application/json'
    },
  });
  businessLatency.add(new Date() - createStartTime);
  
  const createSuccess = check(createRes, {
    'create status is 201': (r) => r.status === 201,
    'create returns item id': (r) => r.json('id') !== undefined,
  });
  
  createItemSuccessRate.add(createSuccess ? 1 : 0);
  
  if (createSuccess) {
    const itemId = createRes.json('id');
    createdItemIds.push(itemId);
    
    sleep(1);
    
    // Get the created item
    const getStartTime = new Date();
    const getRes = http.get(\`\${BASE_URL}/api/items/\${itemId}\`, {
      headers: { 
        'Authorization': \`Bearer \${AUTH_TOKEN}\`,
        'Content-Type': 'application/json'
      },
    });
    businessLatency.add(new Date() - getStartTime);
    
    getItemSuccessRate.add(
      check(getRes, {
        'get status is 200': (r) => r.status === 200,
        'get returns correct item': (r) => r.json('id') === itemId,
      }) ? 1 : 0
    );
    
    sleep(1);
    
    // Update the item
    const updatedItemData = {
      ...itemData,
      name: \`Updated \${itemData.name}\`,
      price: parseFloat((itemData.price * 1.1).toFixed(2))
    };
    
    const updateStartTime = new Date();
    const updateRes = http.put(\`\${BASE_URL}/api/items/\${itemId}\`, JSON.stringify(updatedItemData), {
      headers: { 
        'Authorization': \`Bearer \${AUTH_TOKEN}\`,
        'Content-Type': 'application/json'
      },
    });
    businessLatency.add(new Date() - updateStartTime);
    
    updateItemSuccessRate.add(
      check(updateRes, {
        'update status is 200': (r) => r.status === 200,
        'update returns updated item': (r) => r.json('name') === updatedItemData.name,
      }) ? 1 : 0
    );
    
    sleep(1);
    
    // Delete the item (only delete some items to keep some for GET requests)
    if (Math.random() < 0.3) {
      const deleteStartTime = new Date();
      const deleteRes = http.del(\`\${BASE_URL}/api/items/\${itemId}\`, null, {
        headers: { 
          'Authorization': \`Bearer \${AUTH_TOKEN}\`,
          'Content-Type': 'application/json'
        },
      });
      businessLatency.add(new Date() - deleteStartTime);
      
      deleteItemSuccessRate.add(
        check(deleteRes, {
          'delete status is 204': (r) => r.status === 204,
        }) ? 1 : 0
      );
      
      // Remove from our array
      createdItemIds = createdItemIds.filter(id => id !== itemId);
    }
  }
  
  // Get all items (with pagination)
  const getAllRes = http.get(\`\${BASE_URL}/api/items?limit=10&page=1\`, {
    headers: { 
      'Authorization': \`Bearer \${AUTH_TOKEN}\`,
      'Content-Type': 'application/json'
    },
  });
  
  check(getAllRes, {
    'get all status is 200': (r) => r.status === 200,
    'get all returns array': (r) => Array.isArray(r.json()),
  });
  
  sleep(2);
}
EOF

# Create end-to-end load test script
cat > /home/ubuntu/aws-cloudsec-microservices/testing/load/end-to-end-test.js << EOF
import http from 'k6/http';
import { sleep, check, group } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';

// Custom metrics
const endToEndSuccessRate = new Rate('end_to_end_success_rate');
const endToEndLatency = new Trend('end_to_end_latency');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp-up to 20 users
    { duration: '5m', target: 20 },   // Stay at 20 users for 5 minutes
    { duration: '30s', target: 0 },   // Ramp-down to 0 users
  ],
  thresholds: {
    'http_req_duration': ['p(95)<800'],  // 95% of requests should be below 800ms
    'end_to_end_success_rate': ['rate>0.90'],  // 90% of end-to-end flows should succeed
  },
};

// Service URLs
const AUTH_SERVICE_URL = 'http://localhost:3000';
const BUSINESS_SERVICE_URL = 'http://localhost:3001';
const FRONTEND_SERVICE_URL = 'http://localhost:3002';

// Main test function
export default function() {
  const flowStartTime = new Date();
  let flowSuccess = true;
  
  // Generate random user data
  const userData = {
    username: \`user_\${randomString(8)}\`,
    email: \`\${randomString(8)}@example.com\`,
    password: \`Password\${randomString(4)}!\`
  };
  
  // Step 1: Register a new user
  let userId;
  group('User Registration', function() {
    const registerRes = http.post(\`\${AUTH_SERVICE_URL}/auth/register\`, JSON.stringify(userData), {
      headers: { 'Content-Type': 'application/json' },
    });
    
    const registerSuccess = check(registerRes, {
      'register status is 201': (r) => r.status === 201,
      'register has userId': (r) => r.json('userId') !== undefined,
    });
    
    if (!registerSuccess) flowSuccess = false;
    else userId = registerRes.json('userId');
  });
  
  sleep(1);
  
  // Step 2: Login with the registered user
  let authToken;
  group('User Login', function() {
    const loginRes = http.post(\`\${AUTH_SERVICE_URL}/auth/login\`, JSON.stringify({
      username: userData.username,
      password: userData.password
    }), {
      headers: { 'Content-Type': 'application/json' },
    });
    
    const loginSuccess = check(loginRes, {
      'login status is 200': (r) => r.status === 200,
      'login returns token': (r) => r.json('token') !== undefined,
    });
    
    if (!loginSuccess) flowSuccess = false;
    else authToken = loginRes.json('token');
  });
  
  if (!authToken) {
    endToEndSuccessRate.add(0);
    return;
  }
  
  sleep(1);
  
  // Step 3: Create a business item
  let itemId;
  group('Create Business Item', function() {
    const itemData = {
      name: \`Item \${randomString(8)}\`,
      description: \`Description for item \${randomString(12)}\`,
      category: \`category-\${Math.floor(Math.random() * 5) + 1}\`,
      price: parseFloat((Math.random() * 100 + 10).toFixed(2))
    };
    
    const createRes = http.post(\`\${BUSINESS_SERVICE_URL}/api/items\`, JSON.stringify(itemData), {
      headers: { 
        'Authorization': \`Bearer \${authToken}\`,
        'Content-Type': 'application/json'
      },
    });
    
    const createSuccess = check(createRes, {
      'create status is 201': (r) => r.status === 201,
      'create returns item id': (r) => r.json('id') !== undefined,
    });
    
    if (!createSuccess) flowSuccess = false;
    else itemId = createRes.json('id');
  });
  
  if (!itemId) {
    endToEndSuccessRate.add(0);
    return;
  }
  
  sleep(1);
  
  // Step 4: Get the created item
  group('Get Business Item', function() {
    const getRes = http.get(\`\${BUSINESS_SERVICE_URL}/api/items/\${itemId}\`, {
      headers: { 
        'Authorization': \`Bearer \${authToken}\`,
        'Content-Type': 'application/json'
      },
    });
    
    const getSuccess = check(getRes, {
      'get status is 200': (r) => r.status === 200,
      'get returns correct item': (r) => r.json('id') === itemId,
    });
    
    if (!getSuccess) flowSuccess = false;
  });
  
  sleep(1);
  
  // Step 5: Update the item
  group('Update Business Item', function() {
    const updatedItemData = {
      name: \`Updated Item \${randomString(8)}\`,
      description: \`Updated description \${randomString(12)}\`,
      category: \`updated-category-\${Math.floor(Math.random() * 5) + 1}\`,
      price: parseFloat((Math.random() * 200 + 20).toFixed(2))
    };
    
    const updateRes = http.put(\`\${BUSINESS_SERVICE_URL}/api/items/\${itemId}\`, JSON.stringify(updatedItemData), {
      headers: { 
        'Authorization': \`Bearer \${authToken}\`,
        'Content-Type': 'application/json'
      },
    });
    
    const updateSuccess = check(updateRes, {
      'update status is 200': (r) => r.status === 200,
      'update returns updated item': (r) => r.json('name') === updatedItemData.name,
    });
    
    if (!updateSuccess) flowSuccess = false;
  });
  
  sleep(1);
  
  // Step 6: Delete the item
  group('Delete Business Item', function() {
    const deleteRes = http.del(\`\${BUSINESS_SERVICE_URL}/api/items/\${itemId}\`, null, {
      headers: { 
        'Authorization': \`Bearer \${authToken}\`,
        'Content-Type': 'application/json'
      },
    });
    
    const deleteSuccess = check(deleteRes, {
      'delete status is 204': (r) => r.status === 204,
    });
    
    if (!deleteSuccess) flowSuccess = false;
  });
  
  // Record end-to-end metrics
  endToEndLatency.add(new Date() - flowStartTime);
  endToEndSuccessRate.add(flowSuccess ? 1 : 0);
  
  sleep(2);
}
EOF

echo "Running load tests..."

# Run authentication service load test
echo "Running authentication service load test..."
k6 run --out json=/home/ubuntu/aws-cloudsec-microservices/testing/load/reports/auth-service-results.json /home/ubuntu/aws-cloudsec-microservices/testing/load/auth-service-test.js

# Run business service load test
echo "Running business service load test..."
k6 run --out json=/home/ubuntu/aws-cloudsec-microservices/testing/load/reports/business-service-results.json /home/ubuntu/aws-cloudsec-microservices/testing/load/business-service-test.js

# Run end-to-end load test
echo "Running end-to-end load test..."
k6 run --out json=/home/ubuntu/aws-cloudsec-microservices/testing/load/reports/end-to-end-results.json /home/ubuntu/aws-cloudsec-microservices/testing/load/end-to-
(Content truncated due to size limit. Use line ranges to read in chunks)