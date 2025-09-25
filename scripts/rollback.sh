#!/bin/bash

# Rollback canary deployment using Lambda alias weighted routing
# Usage: ./scripts/rollback.sh [stage]

set -e

# Default values
STAGE=${1:-prod}
REGION=${AWS_REGION:-us-east-1}
FUNCTION_NAME="canary-aws-ping-${STAGE}-ping"

echo "⚠️  Starting rollback procedure..."
echo "   Stage: $STAGE"
echo "   Region: $REGION"
echo "   Function: $FUNCTION_NAME"

# Get current Live alias configuration
echo "📋 Getting current alias configuration..."
ALIAS_INFO=$(aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Live" \
  --query '{FunctionVersion:FunctionVersion,RoutingConfig:RoutingConfig}' \
  --output json \
  --region "$REGION")

echo "Current alias info: $ALIAS_INFO"

# Check if there's weighted routing active
ROUTING_CONFIG=$(echo "$ALIAS_INFO" | jq -r '.RoutingConfig.AdditionalVersionWeights // empty')

if [ -n "$ROUTING_CONFIG" ] && [ "$ROUTING_CONFIG" != "null" ] && [ "$ROUTING_CONFIG" != "{}" ]; then
  echo "🔄 Weighted routing detected - removing canary traffic"
  
  STABLE_VERSION=$(echo "$ALIAS_INFO" | jq -r '.FunctionVersion')
  echo "📋 Rolling back to stable version: $STABLE_VERSION"
  
  # Remove routing configuration (send all traffic to stable version)
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "Live" \
    --function-version "$STABLE_VERSION" \
    --region "$REGION"
  
  echo "✅ Rollback completed!"
  echo "📊 All traffic (100%) now goes to stable version $STABLE_VERSION"
  
else
  CURRENT_VERSION=$(echo "$ALIAS_INFO" | jq -r '.FunctionVersion')
  echo "ℹ️  No active canary traffic detected"
  echo "📊 All traffic already goes to version $CURRENT_VERSION"
fi

# Show recent versions for manual rollback option
echo ""
echo "📚 Recent versions available:"
aws lambda list-versions-by-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Versions[-5:].{Version:Version,Description:Description,LastModified:LastModified}' \
  --output table \
  --region "$REGION"

echo ""
echo "💡 To manually rollback to a specific version:"
echo "   aws lambda update-alias --function-name $FUNCTION_NAME --name Live --function-version VERSION_NUMBER --region $REGION"

echo "🔍 Monitor with: ./scripts/monitor-canary.sh $STAGE"