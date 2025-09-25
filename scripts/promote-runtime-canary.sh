#!/bin/bash

# Promote multi-runtime canary using API Gateway canary deployment
# Usage: ./scripts/promote-runtime-canary.sh [weight] [stage]

set -e

# Default values
WEIGHT=${1:-100}
STAGE=${2:-prod}
REGION=${AWS_REGION:-us-east-1}

echo "🔄 Promoting multi-runtime canary deployment..."
echo "   Stage: $STAGE"
echo "   New Weight: $WEIGHT%"
echo "   Region: $REGION"

# Validate weight
if [ "$WEIGHT" -lt 1 ] || [ "$WEIGHT" -gt 100 ]; then
  echo "❌ Error: Weight must be between 1 and 100"
  exit 1
fi

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
echo "📋 Getting current canary configuration..."
CANARY_SETTINGS=$(aws apigateway get-stage \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" \
  --query 'canarySettings' \
  --output json \
  --region "$REGION")

if [ "$CANARY_SETTINGS" = "null" ] || [ -z "$CANARY_SETTINGS" ]; then
  echo "❌ Error: No canary deployment found"
  echo "ℹ️  Run deploy-runtime-canary.sh first to create a canary deployment"
  exit 1
fi

echo "📋 Current canary settings: $CANARY_SETTINGS"

# If promoting to 100%, switch primary method to canary function
if [ "$WEIGHT" -eq 100 ]; then
  echo "🎯 Full promotion: Switching to canary runtime (Node 22)"
  
  # Get canary function ARN
  CANARY_FUNCTION_ARN=$(aws cloudformation describe-stacks \
    --stack-name "canary-aws-ping-multi-${STAGE}" \
    --query 'Stacks[0].Outputs[?OutputKey==`CanaryFunctionArn`].OutputValue' \
    --output text \
    --region "$REGION")
  
  # Get ping resource ID
  PING_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id "$API_ID" \
    --query 'items[?pathPart==`ping`].id' \
    --output text \
    --region "$REGION")
  
  echo "📋 Switching main method to canary function (Node 22)"
  
  # Update main method integration to use canary function
  aws apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$PING_RESOURCE_ID" \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${CANARY_FUNCTION_ARN}/invocations" \
    --region "$REGION" >/dev/null
  
  # Create new deployment without canary
  DEPLOYMENT_ID=$(aws apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE" \
    --description "Full promotion to Node 22 $(date -u +%Y-%m-%dT%H:%M:%S)" \
    --query 'id' \
    --output text \
    --region "$REGION")
  
  # Remove canary settings (100% promotion)
  aws apigateway update-stage \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE" \
    --patch-ops op=remove,path=/canarySettings \
    --region "$REGION" >/dev/null
  
  echo "✅ Full promotion completed!"
  echo "📊 All traffic (100%) now goes to Node 22 runtime"
  
else
  # Partial promotion - update canary percentage
  echo "📊 Partial promotion: ${WEIGHT}% to canary runtime (Node 22)"
  
  aws apigateway update-stage \
    --rest-api-id "$API_ID" \
    --stage-name "$STAGE" \
    --patch-ops op=replace,path=/canarySettings/percentTraffic,value=$WEIGHT \
    --region "$REGION" >/dev/null
  
  echo "✅ Partial promotion completed!"
  echo "📊 Traffic split: $((100 - WEIGHT))% Node 18, ${WEIGHT}% Node 22"
fi

# Show current endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text \
  --region "$REGION")

echo ""
echo "🎯 Promotion Summary:"
echo "   API Endpoint: $API_ENDPOINT/ping"
if [ "$WEIGHT" -eq 100 ]; then
  echo "   Runtime: Node 22 (100% traffic)"
else
  echo "   Stable Runtime: Node 18 ($((100 - WEIGHT))% traffic)"
  echo "   Canary Runtime: Node 22 (${WEIGHT}% traffic)"
fi
echo ""
echo "📊 Test the deployment:"
echo "   curl $API_ENDPOINT/ping"
echo ""
echo "🔍 Monitor with: ./scripts/monitor-runtime-canary.sh $STAGE"