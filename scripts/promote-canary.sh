#!/bin/bash

# Promote canary using Lambda alias weighted routing
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

# Get current alias configuration
echo "📋 Getting current alias configuration..."
ALIAS_INFO=$(aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Live" \
  --query '{FunctionVersion:FunctionVersion,RoutingConfig:RoutingConfig}' \
  --output json \
  --region "$REGION")

# Extract canary version from routing config
CANARY_VERSION=$(echo "$ALIAS_INFO" | jq -r '.RoutingConfig.AdditionalVersionWeights | keys[0] // empty')

if [ -z "$CANARY_VERSION" ] || [ "$CANARY_VERSION" = "null" ]; then
  echo "❌ Error: No canary deployment found in routing configuration"
  echo "ℹ️  Run deploy-canary.sh first to create a canary deployment"
  exit 1
fi

echo "📋 Current canary version: $CANARY_VERSION"

# If promoting to 100%, move Live alias to canary version
if [ "$WEIGHT" -eq 100 ]; then
  echo "🎯 Full promotion: Moving Live alias to version $CANARY_VERSION"
  
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "Live" \
    --function-version "$CANARY_VERSION" \
    --region "$REGION"
  
  echo "✅ Full promotion completed!"
  echo "📊 All traffic (100%) now goes to version $CANARY_VERSION"
  
else
  # Partial promotion - update traffic weights
  CANARY_WEIGHT=$(printf "%.2f" $(echo "scale=2; $WEIGHT / 100" | bc))
  
  echo "📊 Partial promotion: ${WEIGHT}% to canary version $CANARY_VERSION"
  
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "Live" \
    --routing-config "AdditionalVersionWeights={\"$CANARY_VERSION\":$CANARY_WEIGHT}" \
    --region "$REGION"
  
  echo "✅ Partial promotion completed!"
  echo "📊 Traffic split: $((100 - WEIGHT))% stable, ${WEIGHT}% canary"
fi

echo "🔍 Monitor with: ./scripts/monitor-canary.sh $STAGE"