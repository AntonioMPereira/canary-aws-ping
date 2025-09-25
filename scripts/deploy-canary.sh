#!/bin/bash

# Canary deployment script using Lambda alias weighted routing
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

# Step 1: Deploy new code with Serverless
echo "📦 Deploying new version with Serverless..."
serverless deploy \
  --stage "$STAGE" \
  --region "$REGION" \
  --verbose

# Step 2: Publish new Lambda version  
echo "🔖 Publishing new Lambda version..."
NEW_VERSION=$(aws lambda publish-version \
  --function-name "$FUNCTION_NAME" \
  --description "Canary deployment $(date -u +%Y-%m-%dT%H:%M:%S)" \
  --query 'Version' \
  --output text \
  --region "$REGION")

echo "✅ New version published: $NEW_VERSION"

# Step 3: Configure weighted routing on Live alias
LIVE_WEIGHT=$((100 - WEIGHT))

echo "📊 Configuring traffic splitting..."
echo "   Live (current): ${LIVE_WEIGHT}%"  
echo "   Canary (v${NEW_VERSION}): ${WEIGHT}%"

# Update Live alias with weighted routing
aws lambda update-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Live" \
  --routing-config "AdditionalVersionWeights={\"$NEW_VERSION\":$(printf "%.2f" $(echo "scale=2; $WEIGHT / 100" | bc))}" \
  --region "$REGION"

echo "✅ Canary deployment completed!"
echo "🔍 Monitor with: ./scripts/monitor-canary.sh $STAGE"
echo "🚀 Promote with: ./scripts/promote-canary.sh 50 $STAGE"

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