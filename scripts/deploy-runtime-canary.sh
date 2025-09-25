#!/bin/bash

# Multi-runtime canary deployment script using API Gateway canary deployment
# Usage: ./scripts/deploy-runtime-canary.sh [weight] [stage]

set -e

# Default values
WEIGHT=${1:-10}
STAGE=${2:-prod}
REGION=${AWS_REGION:-us-east-1}

echo "🚀 Starting multi-runtime canary deployment..."
echo "   Stage: $STAGE"
echo "   Canary Weight: $WEIGHT%"
echo "   Region: $REGION"
echo "   Stable Runtime: Node 18.x"
echo "   Canary Runtime: Node 22.x"

# Validate weight
if [ "$WEIGHT" -lt 1 ] || [ "$WEIGHT" -gt 100 ]; then
  echo "❌ Error: Weight must be between 1 and 100"
  exit 1
fi

# Check dependencies
command -v aws >/dev/null 2>&1 || { echo "❌ Error: aws CLI is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "❌ Error: jq is required but not installed."; exit 1; }

# Step 1: Deploy both Lambda functions
echo "📦 Deploying multi-runtime functions with Serverless..."
serverless deploy \
  --config serverless-multi-runtime.yml \
  --stage "$STAGE" \
  --region "$REGION" \
  --verbose

# Step 2: Get API Gateway information
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

# Step 3: Get function ARNs
STABLE_FUNCTION_ARN=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`StableFunctionArn`].OutputValue' \
  --output text \
  --region "$REGION")

CANARY_FUNCTION_ARN=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`CanaryFunctionArn`].OutputValue' \
  --output text \
  --region "$REGION")

echo "📋 Stable Function (Node 18): $STABLE_FUNCTION_ARN"
echo "📋 Canary Function (Node 22): $CANARY_FUNCTION_ARN"

# Step 4: Update /ping method to use canary function for canary traffic
echo "🔄 Updating API Gateway method for canary routing..."

# Get the ping resource ID
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

# Step 5: Create deployment with canary settings
echo "📊 Creating deployment with canary settings..."
echo "   Stable (Node 18): $((100 - WEIGHT))%"  
echo "   Canary (Node 22): ${WEIGHT}%"

# Create new deployment
DEPLOYMENT_ID=$(aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" \
  --description "Multi-runtime canary deployment $(date -u +%Y-%m-%dT%H:%M:%S)" \
  --canary-settings percentTraffic=$WEIGHT,stageVariableOverrides='{runtimeType=canary}' \
  --query 'id' \
  --output text \
  --region "$REGION")

if [ -z "$DEPLOYMENT_ID" ]; then
  echo "❌ Error: Failed to create deployment with canary settings"
  exit 1
fi

echo "✅ Deployment created: $DEPLOYMENT_ID"

# Step 6: Update stage to use deployment with canary
echo "🎯 Updating stage with canary configuration..."

# Patch method integration for canary traffic
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$PING_RESOURCE_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${CANARY_FUNCTION_ARN}/invocations" \
  --region "$REGION" >/dev/null

# Update stage canary settings
aws apigateway update-stage \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" \
  --patch-ops op=replace,path=/canarySettings/percentTraffic,value=$WEIGHT \
  --patch-ops op=replace,path=/canarySettings/deploymentId,value=$DEPLOYMENT_ID \
  --patch-ops op=replace,path=/canarySettings/stageVariableOverrides/runtimeType,value=canary \
  --region "$REGION" >/dev/null

echo "✅ Multi-runtime canary deployment completed!"

# Step 7: Show deployment information
API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text \
  --region "$REGION")

echo ""
echo "🎯 Deployment Summary:"
echo "   API Endpoint: $API_ENDPOINT/ping"
echo "   Stable Runtime: Node 18 ($((100 - WEIGHT))% traffic)"
echo "   Canary Runtime: Node 22 (${WEIGHT}% traffic)"
echo "   Deployment ID: $DEPLOYMENT_ID"
echo ""
echo "📊 Test the deployment:"
echo "   curl $API_ENDPOINT/ping"
echo "   # Run multiple times to see both runtimes"
echo ""
echo "🔍 Monitor with: ./scripts/monitor-runtime-canary.sh $STAGE"
echo "🚀 Promote with: ./scripts/promote-runtime-canary.sh 50 $STAGE"
echo "🔄 Rollback with: ./scripts/rollback-runtime-canary.sh $STAGE"