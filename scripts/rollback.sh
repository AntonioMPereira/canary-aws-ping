#!/bin/bash

# Rollback canary deployment to previous stable version
# Usage: ./scripts/rollback.sh [stage]

set -e

# Default values
STAGE=${1:-prod}
REGION=${AWS_REGION:-us-east-1}

echo "⚠️  Starting rollback procedure..."
echo "   Stage: $STAGE"
echo "   Region: $REGION"

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
  echo "🛑 Stopping current deployment: $DEPLOYMENT_ID"
  
  # Stop the current deployment
  aws deploy stop-deployment \
    --deployment-id "$DEPLOYMENT_ID" \
    --auto-rollback-enabled \
    --region "$REGION"
  
  if [ $? -eq 0 ]; then
    echo "✅ Deployment stopped and rolled back successfully"
  else
    echo "❌ Failed to stop deployment, attempting manual rollback..."
  fi
  
else
  echo "ℹ️  No active deployment found, performing manual rollback..."
fi

# Get the previous stable version
echo "🔍 Finding previous stable version..."
PREVIOUS_VERSION=$(aws lambda list-versions-by-function \
  --function-name "canary-aws-ping-$STAGE-ping" \
  --query 'Versions[?Version != `$LATEST`] | [-2].Version' \
  --output text \
  --region "$REGION" 2>/dev/null || echo "")

if [ -n "$PREVIOUS_VERSION" ] && [ "$PREVIOUS_VERSION" != "None" ]; then
  echo "📦 Rolling back to version: $PREVIOUS_VERSION"
  
  # Update alias to point to previous version
  aws lambda update-alias \
    --function-name "canary-aws-ping-$STAGE-ping" \
    --name "live" \
    --function-version "$PREVIOUS_VERSION" \
    --routing-config AdditionalVersionWeights={} \
    --region "$REGION"
  
  if [ $? -eq 0 ]; then
    echo "✅ Rollback completed successfully!"
    echo "   All traffic is now routed to version $PREVIOUS_VERSION"
    
    # Get the API Gateway endpoint
    ENDPOINT=$(serverless info --stage "$STAGE" --region "$REGION" | grep "GET - " | awk '{print $3}')
    
    if [ -n "$ENDPOINT" ]; then
      echo "🔗 Test endpoint: $ENDPOINT"
      echo "🧪 Testing rollback..."
      
      # Test the endpoint
      RESPONSE=$(curl -s -w "\n%{http_code}" "$ENDPOINT" || echo "")
      HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
      
      if [ "$HTTP_CODE" = "200" ]; then
        echo "✅ Rollback verification successful (HTTP $HTTP_CODE)"
      else
        echo "⚠️  Rollback verification failed (HTTP $HTTP_CODE)"
      fi
    fi
  else
    echo "❌ Rollback failed"
    exit 1
  fi
  
else
  echo "❌ Could not find previous version for rollback"
  exit 1
fi