#!/bin/bash

# Rollback multi-runtime canary deployment using API Gateway
# Usage: ./scripts/rollback-runtime-canary.sh [stage]

set -e

# Default values
STAGE=${1:-prod}
REGION=${AWS_REGION:-us-east-1}

echo "⚠️  Starting multi-runtime canary rollback..."
echo "   Stage: $STAGE"
echo "   Region: $REGION"

# Check dependencies
command -v aws >/dev/null 2>&1 || { echo "❌ Error: aws CLI is required but not installed."; exit 1; }

# Get API Gateway ID
echo "🔍 Getting API Gateway information..."
API_ID=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayRestApiId`].OutputValue' \
  --output text \
  --region "$REGION")

if [ -z "$API_ID" ]; then
  echo "❌ Error: Could not find API Gateway ID from CloudFormation stack"
  exit 1
fi

echo "📋 API Gateway ID: $API_ID"

# Get current canary settings
echo "📋 Checking current canary configuration..."
CANARY_SETTINGS=$(aws apigateway get-stage \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" \
  --query 'canarySettings' \
  --output json \
  --region "$REGION")

if [ "$CANARY_SETTINGS" = "null" ] || [ -z "$CANARY_SETTINGS" ]; then
  echo "ℹ️  No active canary deployment detected"
  echo "📋 Ensuring main method uses stable function (Node 18)..."
else
  echo "🔄 Active canary detected - removing canary deployment"
fi

# Get function ARNs
STABLE_FUNCTION_ARN=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`StableFunctionArn`].OutputValue' \
  --output text \
  --region "$REGION")

echo "📋 Rolling back to stable function (Node 18): $STABLE_FUNCTION_ARN"

# Get ping resource ID
PING_RESOURCE_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items[?pathPart==`ping`].id' \
  --output text \
  --region "$REGION")

if [ -z "$PING_RESOURCE_ID" ]; then
  echo "❌ Error: Could not find /ping resource in API Gateway"
  exit 1
fi

echo "📋 Ping Resource ID: $PING_RESOURCE_ID"

# Update main method integration to use stable function
echo "🔄 Updating method integration to stable function (Node 18)..."
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$PING_RESOURCE_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${STABLE_FUNCTION_ARN}/invocations" \
  --region "$REGION" >/dev/null

# Create new deployment without canary
echo "🚀 Creating rollback deployment..."
DEPLOYMENT_ID=$(aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" \
  --description "Rollback to stable Node 18 $(date -u +%Y-%m-%dT%H:%M:%S)" \
  --query 'id' \
  --output text \
  --region "$REGION")

echo "✅ Rollback deployment created: $DEPLOYMENT_ID"

# Remove canary settings if they exist
if [ "$CANARY_SETTINGS" != "null" ] && [ -n "$CANARY_SETTINGS" ]; then
  echo "🧹 Removing canary configuration..."
  aws apigateway update-stage \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE" \
    --patch-ops op=remove,path=/canarySettings \
    --region "$REGION" >/dev/null
  
  echo "✅ Canary configuration removed"
fi

echo "✅ Rollback completed!"
echo "📊 All traffic (100%) now goes to stable runtime (Node 18)"

# Show current endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text \
  --region "$REGION")

echo ""
echo "🎯 Rollback Summary:"
echo "   API Endpoint: $API_ENDPOINT/ping"
echo "   Runtime: Node 18 (100% traffic - stable)"
echo "   Previous canary: Removed"
echo ""
echo "📊 Test the rollback:"
echo "   curl $API_ENDPOINT/ping"
echo "   # Should always return Node 18 runtime"
echo ""
echo "💡 To deploy a new canary:"
echo "   ./scripts/deploy-runtime-canary.sh 10 $STAGE"
echo ""
echo "🔍 Monitor with: ./scripts/monitor-runtime-canary.sh $STAGE"