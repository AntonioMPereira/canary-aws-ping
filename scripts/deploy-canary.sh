#!/bin/bash

# Canary deployment script using Lambda aliases
# Usage: ./scripts/deploy-canary.sh [weight] [stage]

set -e

# Default values
WEIGHT=${1:-10}
STAGE=${2:-prod}
REGION=${AWS_REGION:-us-east-1}
FUNCTION_NAME="canary-aws-ping-${STAGE}-ping"

echo "🚀 Starting canary deployment..."
echo "   Stage: $STAGE"
echo "   Canary Weight: $WEIGHT%"
echo "   Region: $REGION"
echo "   Function: $FUNCTION_NAME"

# Validate weight
if [ "$WEIGHT" -lt 1 ] || [ "$WEIGHT" -gt 100 ]; then
  echo "❌ Error: Weight must be between 1 and 100"
  exit 1
fi

# Deploy new version
echo "📦 Deploying new version..."
serverless deploy \
  --stage "$STAGE" \
  --region "$REGION" \
  --verbose

# Get the new version number
NEW_VERSION=$(aws lambda list-versions-by-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Versions[-1].Version' \
  --output text \
  --region "$REGION")

echo "✅ New version deployed: $NEW_VERSION"

# Update Canary alias to point to new version
echo "🔄 Updating Canary alias to version $NEW_VERSION..."
aws lambda update-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Canary" \
  --function-version "$NEW_VERSION" \
  --region "$REGION"

# Configure traffic splitting
LIVE_WEIGHT=$((100 - WEIGHT))

echo "📊 Configuring traffic splitting..."
echo "   Live (stable): ${LIVE_WEIGHT}%"  
echo "   Canary (new): ${WEIGHT}%"

# Update alias with traffic splitting
aws lambda update-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Live" \
  --routing-config "AdditionalVersionWeights={\"$NEW_VERSION\":$WEIGHT}" \
  --region "$REGION"

echo "✅ Canary deployment completed!"
echo "🔍 Monitor with: ./scripts/monitor-canary.sh $STAGE"

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