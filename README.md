# Canary AWS Ping

AWS Lambda function with **TWO canary deployment approaches** for ping service.

## 🎯 TWO APPROACHES AVAILABLE

### APPROACH 1: Lambda Weighted Routing (Same Runtime)
- **Use case**: Code changes within same Node.js runtime
- **Configuration**: `serverless.yml`
- **Traffic split**: Lambda alias weighted routing

### APPROACH 2: Multi-Runtime Deployment (Different Runtimes)  
- **Use case**: Node 18 → Node 22 migration
- **Configuration**: `serverless-multi-runtime.yml`
- **Traffic split**: API Gateway canary deployment

## Features

- 🚀 **AWS Lambda** with Node.js 18/20/22 runtime support
- 🔄 **Two Canary Strategies** (weighted routing + multi-runtime)
- 📊 **CloudWatch Monitoring** with automatic rollback
- ⚡ **Serverless Framework 3.16** for deployment
- 🎯 **Lambda Versioning** with aliases management
- 🌟 **Runtime Migration** support (Node 18 ↔ Node 22)

## API Endpoint

```bash
GET /{stage}/ping
```

**Response:**

```json
{
  "message": "ping v20.x.x",
  "timestamp": "2025-09-24T10:00:00.000Z",
  "version": "1.0.1",
  "stage": "prod",
  "region": "us-east-1"
}
```

## 🤔 WHICH APPROACH TO USE?

### For Code Changes (Same Runtime):
```bash
# Use Lambda Weighted Routing (simpler)
npm run deploy:canary      # Deploy with current approach
npm run promote:canary     # Promote to 100%
npm run rollback          # Emergency rollback
```

### For Runtime Migration (Node 18 → Node 22):
```bash
# Use Multi-Runtime Deployment (complex but works)
npm run deploy:runtime-canary    # 10% Node 22, 90% Node 18
npm run promote:runtime-canary   # 100% Node 22
npm run rollback:runtime-canary  # Back to Node 18
```

**📖 Read [COMPARACAO-ABORDAGENS.md](COMPARACAO-ABORDAGENS.md) for detailed comparison**

## Quick Start

### Prerequisites

- Node.js 20+
- AWS CLI configured with appropriate permissions
- Serverless Framework 3.16+

### Installation

```bash
npm install
```

### Testing

```bash
# Run unit tests
npm test

# Run tests with coverage
npm run test:coverage
```

### Deployment

#### Standard Deployment (Single Runtime):
```bash
# Deploy to development
npm run deploy:dev

# Deploy to production  
npm run deploy:prod
```

#### Multi-Runtime Deployment (Node 18 + Node 22):
```bash
# Deploy both runtimes to development
npm run deploy:multi-dev

# Deploy both runtimes to production
npm run deploy:multi-prod
```

## Canary Deployment

### How It Works

#### APPROACH 1: Lambda Alias Weighted Routing
1. **API Gateway** calls the `Live` alias (via qualifier)
2. **Live Alias** uses weighted routing to split traffic between versions
3. **Same Runtime**: All versions use the same Node.js runtime

#### APPROACH 2: Multi-Runtime Canary Deployment  
1. **Two Lambda Functions**: ping-stable (Node 18) + ping-canary (Node 22)
2. **API Gateway Canary**: Traffic splitting between different functions
3. **Different Runtimes**: Each function can use different runtime

### Architectures

**Weighted Routing** (same runtime):
```
API Gateway → Live Alias → Version 1 (90%) + Version 2 (10%)
                ↓              ↓               ↓  
            Node 20.x      Node 20.x       Node 20.x
```

**Multi-Runtime** (different runtimes):
```
API Gateway → Canary → ping-stable (90%) + ping-canary (10%)
                ↓           ↓                    ↓
            Traffic      Node 18.x           Node 22.x
```

### Deploy with Canary

Deploy a new version with 10% traffic split:

```bash
npm run deploy:canary
```

**What happens:**
1. Deploys new code with Serverless Framework
2. Publishes new Lambda version (e.g., Version 2)
3. Updates `Live` alias with weighted routing: 90% → Version 1, 10% → Version 2

### Promote Canary

Gradually increase traffic to canary version:

```bash
# Increase to 50% traffic
./scripts/promote-canary.sh 50 prod

# Full promotion (100% traffic)  
npm run promote:canary
```

### Rollback

Remove canary traffic and revert to stable version:

```bash
npm run rollback
```

**Note:** Rollback removes weighted routing configuration, sending 100% traffic to the stable version.

## Monitoring

CloudWatch alarms are automatically configured to monitor:

- **Error Rate**: Triggers rollback if errors exceed threshold
- **Latency**: Monitors response times for performance regression
- **Invocation Count**: Tracks traffic distribution between versions

## Project Structure

```
canary-aws-ping/
├── src/
│   └── handlers/
│       └── ping.js          # Lambda function handler
├── scripts/
│   ├── deploy-canary.sh     # Canary deployment script
│   ├── promote-canary.sh    # Traffic promotion script
│   ├── rollback.sh          # Rollback script
│   └── monitor-canary.sh    # Monitoring script
├── tests/
│   └── ping.test.js         # Unit tests
├── serverless.yml           # Infrastructure configuration
├── package.json            # Dependencies and scripts
└── README.md               # This file
```

## Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_PROFILE=default

# Serverless Configuration  
SERVERLESS_STAGE=dev

# Canary Configuration
CANARY_TRAFFIC_WEIGHT=10
ERROR_THRESHOLD=5
LATENCY_THRESHOLD_MS=1000
```

## Scripts Usage

### Prerequisites

- `bc` command for decimal calculations
- `jq` command for JSON parsing
- AWS CLI configured with Lambda permissions

### Canary Management

```bash
# Deploy canary with 20% traffic
./scripts/deploy-canary.sh 20 prod

# Promote canary to 50% traffic
./scripts/promote-canary.sh 50 prod

# Full promotion (100% traffic)
./scripts/promote-canary.sh 100 prod

# Emergency rollback
./scripts/rollback.sh prod

# Monitor deployment
./scripts/monitor-canary.sh prod
```

### Script Details

- **deploy-canary.sh**: Publishes new version + configures weighted routing
- **promote-canary.sh**: Adjusts traffic percentages or fully promotes
- **rollback.sh**: Removes weighted routing, reverts to stable
- **monitor-canary.sh**: Shows CloudWatch metrics and alias status

## AWS Resources Created

The deployment creates:

- **Lambda Function**: `canary-aws-ping-{stage}-ping`
- **API Gateway**: REST API with HTTP events
- **Lambda Aliases**: `Live` and `Canary` for traffic splitting  
- **CloudWatch Alarms**: Error rate and latency monitoring
- **IAM Roles**: Execution permissions for Lambda

## Development Workflow

1. **Make Changes**: Modify code in `src/handlers/ping.js`
2. **Test Locally**: Run `npm test` to validate changes
3. **Deploy Canary**: Use `npm run deploy:canary` for safe deployment
4. **Monitor**: Check CloudWatch metrics and alarms
5. **Promote**: Use `npm run promote:canary` if metrics are good
6. **Rollback**: Use `npm run rollback` if issues detected

## Security

- Lambda function uses least-privilege IAM roles
- API Gateway has CORS enabled for web clients
- CloudWatch logs capture all invocations for debugging
- Serverless deployment bucket uses account-specific naming

## Performance

- **Cold Start**: ~100-200ms for first invocation
- **Warm Response**: ~10-50ms for subsequent calls
- **Memory**: 128MB allocated, typically uses ~30MB
- **Timeout**: 10 seconds configured, typical response <100ms

## Troubleshooting

### Common Issues

1. **Deployment Fails**: Check AWS credentials and permissions
2. **Function Errors**: Review CloudWatch logs for stack traces
3. **High Latency**: Monitor CloudWatch metrics and adjust memory
4. **Canary Issues**: Use rollback script immediately

### Debugging Commands

```bash
# View function logs
serverless logs -f ping --stage prod

# Check deployment status
serverless info --stage prod

# Manual function invoke
serverless invoke -f ping --stage prod
```

## License

MIT License - see LICENSE file for details.