#!/bin/bash

# Rollback canary deployment using Lambda aliases
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

# Get current Live version
LIVE_VERSION=$(aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Live" \
  --query 'FunctionVersion' \
  --output text \
  --region "$REGION")

echo "📋 Current Live version: $LIVE_VERSION"

# Check if there's traffic splitting active
ROUTING_CONFIG=$(aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name "Live" \
  --query 'RoutingConfig.AdditionalVersionWeights' \
  --output text \
  --region "$REGION" 2>/dev/null || echo "")

if [ -n "$ROUTING_CONFIG" ] && [ "$ROUTING_CONFIG" != "None" ]; then
  echo "� Traffic splitting detected - removing canary traffic"
  
  # Remove routing configuration (send all traffic to Live version)
  aws lambda update-alias \
    --function-name "$FUNCTION_NAME" \
    --name "Live" \
    --function-version "$LIVE_VERSION" \
    --region "$REGION"
  
  echo "✅ Rollback completed!"
  echo "📊 All traffic (100%) now goes to Live version $LIVE_VERSION"
  
else
  echo "ℹ️  No active canary traffic detected"
  echo "📊 All traffic already goes to Live version $LIVE_VERSION"
fi

# Get previous versions for manual rollback option
echo ""
echo "📚 Recent versions:"
aws lambda list-versions-by-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Versions[-5:].{Version:Version,Description:Description,LastModified:LastModified}' \
  --output table \
  --region "$REGION"

echo ""
echo "💡 To rollback to a specific version:"
echo "   aws lambda update-alias --function-name $FUNCTION_NAME --name Live --function-version VERSION_NUMBER --region $REGION"

echo "🔍 Monitor with: ./scripts/monitor-canary.sh $STAGE"
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