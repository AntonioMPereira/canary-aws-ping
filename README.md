# Canary AWS Ping

AWS Lambda function with API Gateway canary deployments for ping service using Node.js 20.

## Features

- 🚀 **AWS Lambda** with Node.js 20 runtime
- 🔄 **API Gateway Canary Deployments** with traffic splitting
- 📊 **CloudWatch Monitoring** with automatic rollback
- 🐳 **LocalStack** for local development
- ⚡ **Serverless Framework 3.16** for deployment
- 🎯 **Lambda Versioning** with aliases management

## API Endpoint

```bash
GET /prod/ping
```

**Response:**

```json
{
  "message": "ping v20.x.x",
  "timestamp": "2025-09-24T10:00:00.000Z",
  "version": "1.0.0"
}
```

## Quick Start

### Prerequisites

- Node.js 20+
- AWS CLI configured
- Docker (for LocalStack)

### Installation

```bash
npm install
```

### Local Development

```bash
# Start LocalStack
npm run local:start

# Deploy to local
npm run local:deploy

# Test local endpoint
curl http://localhost:4566/restapis/{api-id}/local/_user_request_/ping
```

### Production Deployment

#### Standard Deploy

```bash
npm run deploy:prod
```

#### Canary Deploy (10% traffic)

```bash
npm run deploy:canary
```

#### Promote Canary (100% traffic)

```bash
npm run promote:canary
```

## 🧪 Testing Guide

### **1. Unit Tests**

Run the Jest test suite:

```bash
# Install dependencies first
npm install

# Run all tests
npm test

# Run tests with coverage
npm run test -- --coverage

# Run tests in watch mode
npm run test -- --watch
```

### **2. Local Testing with LocalStack**

Test the Lambda function locally:

```bash
# Start LocalStack
npm run local:start

# Wait for LocalStack to be ready (check health)
curl http://localhost:4566/health

# Deploy to LocalStack
npm run local:deploy

# Get the local API endpoint
serverless info --stage local

# Test the local endpoint
curl http://localhost:4566/restapis/{api-id}/local/_user_request_/ping
```

### **3. AWS Development Environment Testing**

Test in AWS dev environment:

```bash
# Deploy to AWS dev stage
npm run deploy:dev

# Get the dev endpoint
serverless info --stage dev

# Test the dev endpoint
curl https://{api-id}.execute-api.us-east-1.amazonaws.com/dev/ping
```

### **4. Production Canary Testing**

Test canary deployment in production:

```bash
# Deploy canary (10% traffic)
./scripts/deploy-canary.sh 10 prod

# Monitor the deployment
./scripts/monitor-canary.sh prod 300

# Test the production endpoint (hits both stable and canary)
curl https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping

# Run multiple tests to see traffic distribution
for i in {1..20}; do
  curl -s https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping | jq .message
  sleep 1
done
```

### **5. Load Testing**

Test with higher load to verify canary behavior:

```bash
# Install artillery for load testing
npm install -g artillery

# Create load test configuration
cat > load-test.yml << EOF
config:
  target: 'https://{your-api-id}.execute-api.us-east-1.amazonaws.com'
  phases:
    - duration: 300
      arrivalRate: 10
scenarios:
  - name: "Ping endpoint"
    flow:
      - get:
          url: "/prod/ping"
EOF

# Run load test
artillery run load-test.yml
```

### **6. Monitoring During Tests**

Monitor metrics while testing:

```bash
# In one terminal - run monitoring
./scripts/monitor-canary.sh prod 600

# In another terminal - run tests
for i in {1..100}; do
  curl -s https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping
  sleep 2
done
```

### **7. Error Testing (Rollback Simulation)**

Test error scenarios and rollback:

```bash
# 1. Deploy a version with intentional error
# Edit src/handlers/ping.js to throw an error
sed -i 's/const nodeVersion = process.version;/throw new Error("Test error");/' src/handlers/ping.js

# 2. Deploy canary with error
./scripts/deploy-canary.sh 10 prod

# 3. Test - should trigger alarms
for i in {1..10}; do curl https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping; done

# 4. Monitor alarms (should trigger)
./scripts/monitor-canary.sh prod 120

# 5. Rollback when alarms trigger
./scripts/rollback.sh prod

# 6. Restore original code
git checkout -- src/handlers/ping.js
```

### **8. Complete End-to-End Test**

Full canary deployment lifecycle test:

```bash
# 1. Initial deploy
npm run deploy:prod

# 2. Make a small change (e.g., update version in package.json)
sed -i 's/"version": "1.0.0"/"version": "1.0.1"/' package.json

# 3. Deploy canary
./scripts/deploy-canary.sh 10 prod

# 4. Monitor for 5 minutes
./scripts/monitor-canary.sh prod 300

# 5. Promote to 50%
./scripts/promote-canary.sh 50 prod

# 6. Monitor again
./scripts/monitor-canary.sh prod 300

# 7. Promote to 100%
./scripts/promote-canary.sh 100 prod

# 8. Final verification
curl https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping
```

### **Expected Responses**

#### **Successful Response:**
```json
{
  "message": "ping v20.x.x",
  "timestamp": "2025-09-24T15:30:00.000Z",
  "version": "1.0.0",
  "environment": "prod",
  "requestId": "abc123-def456-ghi789"
}
```

#### **Error Response:**
```json
{
  "error": "Internal Server Error",
  "message": "Failed to process ping request", 
  "timestamp": "2025-09-24T15:30:00.000Z"
}
```

### **Testing Checklist**

- [ ] ✅ Unit tests pass
- [ ] 🐳 LocalStack deployment works
- [ ] 🔧 Dev environment deploys successfully
- [ ] 🚀 Canary deployment creates traffic split
- [ ] 📊 Monitoring shows metrics for both versions
- [ ] ⚡ Load testing shows traffic distribution
- [ ] 🔄 Rollback works in error scenarios
- [ ] 📈 Full promotion completes successfully


#### Rollback

```bash
npm run rollback
```

## Canary Deployment Strategy

1. **Deploy Canary**: New version receives 10% of traffic
2. **Monitor Metrics**: CloudWatch alarms track error rates
3. **Promote or Rollback**: Based on performance metrics
4. **Automatic Rollback**: If error threshold exceeded

## Architecture

```text
API Gateway (prod stage)
├── 90% traffic → Lambda v15 (stable)
└── 10% traffic → Lambda v16 (canary)
```

## Advanced Usage

### Custom Canary Weight

```bash
# Deploy with custom traffic percentage
./scripts/deploy-canary.sh 25 prod

# Promote with specific weight
./scripts/promote-canary.sh 50 prod
```

### Monitoring

```bash
# Monitor canary metrics for 10 minutes
./scripts/monitor-canary.sh prod 600
```

### Manual Rollback

```bash
# Emergency rollback
./scripts/rollback.sh prod
```

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `deploy-canary.sh` | Deploy new version to canary | `./scripts/deploy-canary.sh [weight] [stage]` |
| `promote-canary.sh` | Increase canary traffic | `./scripts/promote-canary.sh [weight] [stage]` |
| `rollback.sh` | Rollback to previous version | `./scripts/rollback.sh [stage]` |
| `monitor-canary.sh` | Monitor deployment metrics | `./scripts/monitor-canary.sh [stage] [duration]` |

## Monitoring & Alarms

### CloudWatch Alarms

- **Error Rate**: Triggers at >0 errors per minute
- **Latency**: Triggers at >1000ms average duration
- **Throttles**: Monitors function throttling

### Metrics Dashboard

Key metrics monitored:
- Invocations per minute
- Error rate percentage
- Average duration
- Throttle count

## Development

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Stop LocalStack
npm run local:stop
```

## Troubleshooting

### Common Issues

1. **LocalStack not starting**
   ```bash
   docker-compose down
   docker-compose up -d
   ```

2. **Deployment timeouts**
   ```bash
   # Increase timeout in serverless.yml
   timeout: 30
   ```

3. **Canary stuck in deployment**
   ```bash
   ./scripts/rollback.sh prod
   ```

## 📋 Project Architecture & File Structure

### **Core Files Overview**

Each file in this project has a specific role in the canary deployment ecosystem:

#### **1. `package.json` - Project Configuration**
**Purpose:** Defines Node.js project dependencies, scripts and metadata
- **`engines`**: Enforces Node.js 20+ requirement
- **`scripts`**: NPM commands for deployment, testing and local development
- **`devDependencies`**: Serverless Framework 3.16 + canary plugins + LocalStack
- **`keywords`**: Project identification tags

#### **2. `src/handlers/ping.js` - Lambda Handler**
**Purpose:** Main Lambda function that responds with "ping {NODE_VERSION}"
- **Returns**: `{"message": "ping v20.x.x", "timestamp": "...", "version": "1.0.0"}`
- **CORS Headers**: Allows cross-origin requests from any domain
- **Error Handling**: Returns 500 status on failures with error details
- **Environment Info**: Includes stage and requestId for debugging

#### **3. `serverless.yml` - Infrastructure as Code**
**Purpose:** Defines entire AWS infrastructure and canary deployment strategy
- **Provider Config**: AWS with Node.js 20 runtime, dynamic staging
- **Function Definition**: HTTP-triggered `ping` function configuration  
- **Canary Settings**: `Canary10Percent5Minutes` with CloudWatch alarms
- **Monitoring**: Error rate and latency alarms with auto-rollback
- **Validation Functions**: Pre/post traffic validation hooks
- **IAM Permissions**: Required roles and policies for deployment

#### **4. `docker-compose.yml` - Local Development Environment**
**Purpose:** LocalStack container to simulate AWS services locally
- **LocalStack 3.0**: Emulates Lambda, API Gateway, CloudWatch services
- **Data Persistence**: Maintains state between container restarts
- **Health Checks**: Monitors container health status
- **Volume Mapping**: Persists data in `/tmp/localstack` directory

### **Deployment Automation Scripts**

#### **`scripts/deploy-canary.sh` - Initial Canary Deploy**
**Purpose:** Deploys new version with traffic splitting (default 10%)
- Validates traffic weight parameters (1-100%)
- Executes `serverless deploy` with canary configuration
- Displays endpoint URLs and monitoring dashboard links

#### **`scripts/promote-canary.sh` - Traffic Promotion**
**Purpose:** Increases canary traffic percentage (50%, 100%)
- Promotes canary version by increasing traffic weight
- Supports continuous deployment or new deployment creation
- Full promotion (100%) makes canary the new stable version

#### **`scripts/rollback.sh` - Emergency Rollback**
**Purpose:** Immediate rollback to previous stable version
- Automatically stops active canary deployments
- Reverts Lambda alias to previous version
- Validates rollback with endpoint health check

#### **`scripts/monitor-canary.sh` - Real-time Monitoring**
**Purpose:** Live metrics monitoring during canary deployment
- Collects CloudWatch metrics (errors, latency, invocations)
- Calculates error rate percentages in real-time
- Triggers automatic alerts when alarm thresholds exceeded

### **Configuration & Testing Files**

#### **`jest.config.js` - Test Configuration**
**Purpose:** Jest testing framework setup
- Coverage reporting (text, HTML, LCOV formats)
- Test file pattern matching
- Node.js test environment configuration

#### **`.env.example` - Environment Template**
**Purpose:** Environment variable configuration template
- AWS settings (region, profile, credentials)
- LocalStack connection parameters
- CloudWatch alarm thresholds and application settings

#### **`tests/ping.test.js` - Unit Tests**
**Purpose:** Comprehensive Lambda function testing
- Tests response format and Node.js version inclusion
- Validates CORS header configuration
- Tests error scenarios and default value handling

### **System Architecture Flow**

```text
┌─ package.json (dependencies)
├─ serverless.yml (infrastructure) → AWS CloudFormation
├─ src/handlers/ping.js (application code) → AWS Lambda
├─ docker-compose.yml (local environment) → LocalStack
└─ scripts/ (deployment automation) → Canary Management
```

### **Deployment Strategy**

The canary deployment process follows this architecture:

1. **Initial Deploy**: `deploy-canary.sh` creates new Lambda version
2. **Traffic Split**: API Gateway routes 10% traffic to new version
3. **Monitoring**: `monitor-canary.sh` watches CloudWatch metrics
4. **Promotion**: `promote-canary.sh` increases traffic (50% → 100%)
5. **Rollback**: `rollback.sh` available for emergency situations

### **Key Benefits**

- **Zero Downtime**: Traffic splitting ensures continuous service
- **Risk Mitigation**: Automatic rollback on error threshold breach
- **Local Testing**: LocalStack provides complete AWS simulation
- **Monitoring**: Real-time metrics and automated alerting
- **Version Control**: Lambda versioning with alias management

## License

MIT