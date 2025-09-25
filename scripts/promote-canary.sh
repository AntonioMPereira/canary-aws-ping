#!/bin/bash

# Promote canary to stable using Lambda aliases
# Usage: ./scripts/promote-canary.sh [weight] [stage]

set -e

# Default values
WEIGHT=${1:-100}
STAGE=${2:-prod}
REGION=${AWS_REGION:-us-east-1}
FUNCTION_NAME="canary-aws-ping-${STAGE}-ping"

echo "🔄 Promoting canary deployment..."
echo "   Stage: $STAGE"
echo "   New Weight: $WEIGHT%"
echo "   Region: $REGION"
echo "   Function: $FUNCTION_NAME"

# Validate weight
if [ "$WEIGHT" -lt 1 ] || [ "$WEIGHT" -gt 100 ]; then
  echo "❌ Error: Weight must be between 1 and 100"
  exit 1
fi

# Get current Canary version
CANARY_VERSION=$(aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Canary" \
  --query 'FunctionVersion' \
  --output text \
  --region "$REGION")

if [ "$CANARY_VERSION" = "None" ] || [ -z "$CANARY_VERSION" ]; then
  echo "❌ Error: No canary deployment found"
  exit 1
fi

echo "📋 Current canary version: $CANARY_VERSION"

# If promoting to 100%, update Live alias to point to canary version
if [ "$WEIGHT" -eq 100 ]; then
  echo "🎯 Full promotion: Moving Live alias to version $CANARY_VERSION"
  
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "Live" \
    --function-version "$CANARY_VERSION" \
    --region "$REGION"
  
  # Remove routing config (100% traffic to Live)
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "Live" \
    --region "$REGION"
    
  echo "✅ Full promotion completed!"
  echo "📊 All traffic (100%) now goes to version $CANARY_VERSION"
  
else
  # Partial promotion - update traffic weights
  LIVE_WEIGHT=$((100 - WEIGHT))
  
  echo "📊 Partial promotion: ${WEIGHT}% to canary"
  echo "   Live (stable): ${LIVE_WEIGHT}%"
  echo "   Canary (new): ${WEIGHT}%"
  
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "Live" \
    --routing-config "AdditionalVersionWeights={\"$CANARY_VERSION\":$WEIGHT}" \
    --region "$REGION"
  
  echo "✅ Partial promotion completed!"
fi

echo "🔍 Monitor with: ./scripts/monitor-canary.sh $STAGE"
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