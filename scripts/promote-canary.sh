#!/bin/bash

# Promote canary to stable (increase traffic weight)
# Usage: ./scripts/promote-canary.sh [weight] [stage]

set -e

# Default values
WEIGHT=${1:-100}
STAGE=${2:-prod}
REGION=${AWS_REGION:-us-east-1}

echo "🔄 Promoting canary deployment..."
echo "   Stage: $STAGE"
echo "   New Weight: $WEIGHT%"
echo "   Region: $REGION"

# Validate weight
if [ "$WEIGHT" -lt 1 ] || [ "$WEIGHT" -gt 100 ]; then
  echo "❌ Error: Weight must be between 1 and 100"
  exit 1
fi

# Get current deployment info
echo "📋 Getting current deployment status..."
DEPLOYMENT_ID=$(aws deploy list-deployments \
  --application-name "canary-aws-ping-$STAGE" \
  --deployment-group-name "ping-deployment-group" \
  --include-only-statuses "InProgress" "Ready" \
  --query 'deployments[0]' \
  --output text \
  --region "$REGION" 2>/dev/null || echo "")

if [ -n "$DEPLOYMENT_ID" ] && [ "$DEPLOYMENT_ID" != "None" ]; then
  echo "🔄 Continuing existing deployment: $DEPLOYMENT_ID"
  
  # Continue deployment with new weight
  aws deploy continue-deployment \
    --deployment-id "$DEPLOYMENT_ID" \
    --deployment-wait-type "READY_WAIT" \
    --region "$REGION"
    
else
  echo "🚀 Creating new promotion deployment..."
  
  # Deploy with increased weight
  serverless deploy \
    --stage "$STAGE" \
    --region "$REGION" \
    --param="canaryWeight=$WEIGHT" \
    --verbose
fi

if [ $? -eq 0 ]; then
  if [ "$WEIGHT" -eq 100 ]; then
    echo "✅ Canary promoted to stable (100% traffic)!"
    echo "   All traffic is now routed to the new version"
  else
    echo "✅ Canary promotion successful!"
    echo "   $WEIGHT% of traffic is now routed to the new version"
  fi
  
  # Get the API Gateway endpoint
  ENDPOINT=$(serverless info --stage "$STAGE" --region "$REGION" | grep "GET - " | awk '{print $3}')
  
  if [ -n "$ENDPOINT" ]; then
    echo "🔗 Test endpoint: $ENDPOINT"
  fi
  
else
  echo "❌ Canary promotion failed"
  exit 1
fi