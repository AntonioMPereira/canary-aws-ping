# Canary AWS Ping

AWS Lambda function with API Gateway canary deployments for ping service using Node.js 20.

## Features

- 🚀 **AWS Lambda** with Node.js 20 runtime
- 🔄 **API Gateway Canary Deployments** with traffic splitting
- 📊 **CloudWatch Monitoring** with automatic rollback
- ⚡ **Serverless Framework 3.16** for deployment
- 🎯 **Lambda Versioning** with aliases management

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

```bash
# Deploy to development
npm run deploy:dev

# Deploy to production
npm run deploy:prod
```

## Canary Deployment

### Deploy with Canary

Deploy a new version with 10% traffic split:

```bash
npm run deploy:canary
```

This runs: `./scripts/deploy-canary.sh 10 prod`

### Promote Canary

After validating canary performance, promote to 100% traffic:

```bash
npm run promote:canary
```

This runs: `./scripts/promote-canary.sh 100 prod`

### Rollback

If issues are detected, rollback to previous version:

```bash
npm run rollback
```

This runs: `./scripts/rollback.sh prod`

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