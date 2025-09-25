# Canary AWS Ping# Canary AWS Ping



AWS Lambda function with API Gateway canary deployments for ping service using Node.js 20.AWS Lambda function with API Gateway canary deployments for ping service using Node.js 20.



## Features## Features



- 🚀 **AWS Lambda** with Node.js 20 runtime- 🚀 **AWS Lambda** with Node.js 20 runtime

- 🔄 **API Gateway Canary Deployments** with traffic splitting- 🔄 **API Gateway Canary Deployments** with traffic splitting

- 📊 **CloudWatch Monitoring** with automatic rollback- 📊 **CloudWatch Monitoring** with automatic rollback

- ⚡ **Serverless Framework 3.16** for deployment- ⚡ **Serverless Framework 3.16** for deployment

- 🎯 **Lambda Versioning** with aliases management- 🎯 **Lambda Versioning** with aliases management



## API Endpoint## API Endpoint



```bash```bash

GET /{stage}/pingGET /{stage}/ping

``````



**Response:****Response:**



```json```json

{{

  "message": "ping v20.x.x",  "message": "ping v20.x.x",

  "timestamp": "2025-01-24T10:00:00.000Z",  "timestamp": "2025-01-24T10:00:00.000Z",

  "version": "1.0.1",  "version": "1.0.1",

  "stage": "prod",  "stage": "prod",

  "region": "us-east-1"  "region": "us-east-1"

}}

``````



## Quick Start## Quick Start



### Prerequisites### Prerequisites



- Node.js 20+- Node.js 20+

- AWS CLI configured with appropriate permissions- AWS CLI configured with appropriate permissions

- Serverless Framework 3.16+

### Installation

### Installation

```bash

```bashnpm install

npm install```

```npm run test:coverage

```

### Testing

### AWS Deployment

```bash

# Run unit tests#### Standard Deploy

npm test

```bash

# Run tests with coveragenpm run deploy:prod

npm run test:coverage```

```

#### Canary Deploy (10% traffic)

### Deployment

```bash

```bashnpm run deploy:canary

# Deploy to development```

npm run deploy:dev

#### Promote Canary (100% traffic)

# Deploy to production

npm run deploy:prod```bash

```npm run promote:canary

```

## Canary Deployment

## 🧪 Testing Guide

### Deploy with Canary

### **1. Unit Tests**

Deploy a new version with 10% traffic split:

Run the Jest test suite:

```bash

npm run deploy:canary```bash

```# Install dependencies first

npm install

This runs: `./scripts/deploy-canary.sh 10 prod`

# Run all tests

### Promote Canarynpm test



After validating canary performance, promote to 100% traffic:# Run tests with coverage

npm run test -- --coverage

```bash

npm run promote:canary# Run tests in watch mode

```npm run test -- --watch

```

This runs: `./scripts/promote-canary.sh 100 prod`

### **2. Local Testing with LocalStack**

### Rollback

Test the Lambda function locally:

If issues are detected, rollback to previous version:

```bash

```bash# Start LocalStack

npm run rollbacknpm run local:start

```

# Wait for LocalStack to be ready (check health)

This runs: `./scripts/rollback.sh prod`curl http://localhost:4566/health



## Monitoring# Deploy to LocalStack

npm run local:deploy

CloudWatch alarms are automatically configured to monitor:

# Get the local API endpoint

- **Error Rate**: Triggers rollback if errors exceed thresholdserverless info --stage local

- **Latency**: Monitors response times for performance regression

- **Invocation Count**: Tracks traffic distribution between versions# Test the local endpoint

curl http://localhost:4566/restapis/{api-id}/local/_user_request_/ping

## Project Structure```



```### **3. AWS Development Environment Testing**

canary-aws-ping/

├── src/Test in AWS dev environment:

│   └── handlers/

│       └── ping.js          # Lambda function handler```bash

├── scripts/# Deploy to AWS dev stage

│   ├── deploy-canary.sh     # Canary deployment scriptnpm run deploy:dev

│   ├── promote-canary.sh    # Traffic promotion script

│   ├── rollback.sh          # Rollback script# Get the dev endpoint

│   └── monitor.sh           # Monitoring scriptserverless info --stage dev

├── tests/

│   └── ping.test.js         # Unit tests# Test the dev endpoint

├── serverless.yml           # Infrastructure configurationcurl https://{api-id}.execute-api.us-east-1.amazonaws.com/dev/ping

├── package.json            # Dependencies and scripts```

└── README.md               # This file

```### **4. Production Canary Testing**



## Environment VariablesTest canary deployment in production:



Copy `.env.example` to `.env` and configure:```bash

# Deploy canary (10% traffic)

```bash./scripts/deploy-canary.sh 10 prod

# AWS Configuration

AWS_REGION=us-east-1# Monitor the deployment

AWS_PROFILE=default./scripts/monitor-canary.sh prod 300



# Serverless Configuration  # Test the production endpoint (hits both stable and canary)

SERVERLESS_STAGE=devcurl https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping



# Canary Configuration# Run multiple tests to see traffic distribution

CANARY_TRAFFIC_WEIGHT=10for i in {1..20}; do

ERROR_THRESHOLD=5  curl -s https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping | jq .message

LATENCY_THRESHOLD_MS=1000  sleep 1

```done

```

## Scripts

### **5. Load Testing**

### Canary Management Scripts

Test with higher load to verify canary behavior:

All scripts are located in the `scripts/` directory and handle:

```bash

1. **`deploy-canary.sh`**: Deploys new version with specified traffic percentage# Install artillery for load testing

2. **`promote-canary.sh`**: Increases traffic to canary versionnpm install -g artillery

3. **`rollback.sh`**: Reverts to previous stable version

4. **`monitor.sh`**: Displays real-time metrics and alerts# Create load test configuration

cat > load-test.yml << EOF

### Usage Examplesconfig:

  target: 'https://{your-api-id}.execute-api.us-east-1.amazonaws.com'

```bash  phases:

# Deploy canary with 20% traffic    - duration: 300

./scripts/deploy-canary.sh 20 prod      arrivalRate: 10

scenarios:

# Promote canary to 50% traffic  - name: "Ping endpoint"

./scripts/promote-canary.sh 50 prod    flow:

      - get:

# Full promotion (100% traffic)          url: "/prod/ping"

./scripts/promote-canary.sh 100 prodEOF



# Emergency rollback# Run load test

./scripts/rollback.sh prodartillery run load-test.yml

```

# Monitor deployment

./scripts/monitor.sh prod### **6. Monitoring During Tests**

```

Monitor metrics while testing:

## AWS Resources

```bash

The deployment creates:# In one terminal - run monitoring

./scripts/monitor-canary.sh prod 600

- **Lambda Function**: `canary-aws-ping-{stage}-ping`

- **API Gateway**: REST API with canary deployment# In another terminal - run tests

- **Lambda Aliases**: `Live` and `Canary` for traffic splitting  for i in {1..100}; do

- **CloudWatch Alarms**: Error rate and latency monitoring  curl -s https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping

- **IAM Roles**: Execution permissions for Lambda  sleep 2

done

## Development Workflow```



1. **Make Changes**: Modify code in `src/handlers/ping.js`### **7. Error Testing (Rollback Simulation)**

2. **Test Locally**: Run `npm test` to validate changes

3. **Deploy Canary**: Use `npm run deploy:canary` for safe deploymentTest error scenarios and rollback:

4. **Monitor**: Check CloudWatch metrics and alarms

5. **Promote**: Use `npm run promote:canary` if metrics are good```bash

6. **Rollback**: Use `npm run rollback` if issues detected# 1. Deploy a version with intentional error

# Edit src/handlers/ping.js to throw an error

## Securitysed -i 's/const nodeVersion = process.version;/throw new Error("Test error");/' src/handlers/ping.js



- Lambda function uses least-privilege IAM roles# 2. Deploy canary with error

- API Gateway has CORS enabled for web clients./scripts/deploy-canary.sh 10 prod

- CloudWatch logs capture all invocations for debugging

- Serverless deployment bucket uses account-specific naming# 3. Test - should trigger alarms

for i in {1..10}; do curl https://{api-id}.execute-api.us-east-1.amazonaws.com/prod/ping; done

## Performance

# 4. Monitor alarms (should trigger)

- **Cold Start**: ~100-200ms for first invocation./scripts/monitor-canary.sh prod 120

- **Warm Response**: ~10-50ms for subsequent calls

- **Memory**: 128MB allocated, typically uses ~30MB# 5. Rollback when alarms trigger

- **Timeout**: 10 seconds configured, typical response <100ms./scripts/rollback.sh prod



## Troubleshooting# 6. Restore original code

git checkout -- src/handlers/ping.js

### Common Issues```



1. **Deployment Fails**: Check AWS credentials and permissions### **8. Complete End-to-End Test**

2. **Function Errors**: Review CloudWatch logs for stack traces

3. **High Latency**: Monitor CloudWatch metrics and adjust memoryFull canary deployment lifecycle test:

4. **Canary Issues**: Use rollback script immediately

```bash

### Debugging Commands# 1. Initial deploy

npm run deploy:prod

```bash

# View function logs# 2. Make a small change (e.g., update version in package.json)

serverless logs -f ping --stage prodsed -i 's/"version": "1.0.0"/"version": "1.0.1"/' package.json



# Check deployment status# 3. Deploy canary

serverless info --stage prod./scripts/deploy-canary.sh 10 prod



# Manual function invoke# 4. Monitor for 5 minutes

serverless invoke -f ping --stage prod./scripts/monitor-canary.sh prod 300

```

# 5. Promote to 50%

## License./scripts/promote-canary.sh 50 prod



MIT License - see LICENSE file for details.# 6. Monitor again
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