#!/bin/bash

# Canary deployment script with traffic splitting
# Usage: ./scripts/deploy-canary.sh [weight] [stage]

set -e

# Default values
WEIGHT=${1:-10}
STAGE=${2:-prod}
REGION=${AWS_REGION:-us-east-1}

echo "🚀 Starting canary deployment..."
echo "   Stage: $STAGE"
echo "   Canary Weight: $WEIGHT%"
echo "   Region: $REGION"

# Validate weight
if [ "$WEIGHT" -lt 1 ] || [ "$WEIGHT" -gt 100 ]; then
  echo "❌ Error: Weight must be between 1 and 100"
  exit 1
fi

# Deploy with canary configuration
echo "📦 Deploying new version to canary..."
serverless deploy \
  --stage "$STAGE" \
  --region "$REGION" \
  --param="canaryWeight=$WEIGHT" \
  --verbose

if [ $? -eq 0 ]; then
  echo "✅ Canary deployment successful!"
  echo "   $WEIGHT% of traffic is now routed to the new version"
  echo "   Monitor CloudWatch alarms for automatic rollback"
  
  # Get the API Gateway endpoint
  ENDPOINT=$(serverless info --stage "$STAGE" --region "$REGION" | grep "GET - " | awk '{print $3}')
  
  if [ -n "$ENDPOINT" ]; then
    echo "🔗 Test endpoint: $ENDPOINT"
    echo "📊 Monitor at: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:"
  fi
  
else
  echo "❌ Canary deployment failed"
  exit 1
fi