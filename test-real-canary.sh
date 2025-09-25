#!/bin/bash

# Real AWS Canary Deployment Test
# Tests actual traffic splitting between Lambda versions

set -e

STAGE=${1:-prod}
REGION=${2:-us-east-1}

echo "🎯 Real AWS Canary Deployment Test"
echo "=================================="
echo "Stage: $STAGE"
echo "Region: $REGION"
echo ""

# Check if AWS credentials are configured
echo "🔐 Checking AWS credentials..."
aws sts get-caller-identity > /dev/null 2>&1
if [ $? -eq 0 ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✅ AWS credentials valid (Account: $ACCOUNT_ID)"
else
    echo "❌ AWS credentials not configured!"
    echo "Run: aws configure"
    exit 1
fi

echo ""

# Step 1: Deploy initial version
echo "🚀 Step 1: Deploy initial version (v1.0.0)"
echo "========================================="
git stash > /dev/null 2>&1 || true
sed -i 's/"version": ".*"/"version": "1.0.0"/' package.json

npm run deploy:prod
if [ $? -ne 0 ]; then
    echo "❌ Initial deploy failed"
    exit 1
fi

# Get endpoint URL
ENDPOINT=$(npx serverless info --stage $STAGE --region $REGION | grep "GET - " | awk '{print $3}')
echo "📍 Endpoint: $ENDPOINT"

echo ""
echo "🧪 Testing initial version..."
for i in {1..5}; do
    RESPONSE=$(curl -s "$ENDPOINT")
    VERSION=$(echo $RESPONSE | jq -r '.version // "unknown"')
    echo "Request $i: Version $VERSION"
done

echo ""
read -p "Press Enter to continue with canary deployment..."

# Step 2: Deploy canary version
echo ""
echo "🐤 Step 2: Deploy canary version (v1.0.1)"  
echo "========================================"
sed -i 's/"version": "1.0.0"/"version": "1.0.1"/' package.json

./scripts/deploy-canary.sh 10 $STAGE
if [ $? -ne 0 ]; then
    echo "❌ Canary deploy failed"
    exit 1
fi

echo ""
echo "📊 Testing traffic distribution (90% v1.0.0, 10% v1.0.1)..."
echo "Making 50 requests to observe traffic splitting:"

V100_COUNT=0
V101_COUNT=0
TOTAL_REQUESTS=50

for i in $(seq 1 $TOTAL_REQUESTS); do
    RESPONSE=$(curl -s "$ENDPOINT")
    VERSION=$(echo $RESPONSE | jq -r '.version // "unknown"')
    
    if [ "$VERSION" = "1.0.0" ]; then
        V100_COUNT=$((V100_COUNT + 1))
        echo -n "🏠"
    elif [ "$VERSION" = "1.0.1" ]; then
        V101_COUNT=$((V101_COUNT + 1))
        echo -n "🐤"
    else
        echo -n "❓"
    fi
    
    # New line every 10 requests
    if [ $((i % 10)) -eq 0 ]; then
        echo " ($i/$TOTAL_REQUESTS)"
    fi
    
    sleep 0.1
done

echo ""
echo ""
echo "📈 Traffic Distribution Results:"
echo "==============================="
V100_PERCENT=$((V100_COUNT * 100 / TOTAL_REQUESTS))
V101_PERCENT=$((V101_COUNT * 100 / TOTAL_REQUESTS))

echo "🏠 Stable v1.0.0:  $V100_COUNT requests ($V100_PERCENT%)"
echo "🐤 Canary v1.0.1:  $V101_COUNT requests ($V101_PERCENT%)"

# Validate distribution
if [ $V101_PERCENT -ge 5 ] && [ $V101_PERCENT -le 15 ]; then
    echo "✅ Canary traffic distribution is correct (~10%)"
else
    echo "⚠️  Canary traffic distribution outside expected range (5-15%)"
fi

echo ""
echo "🎯 Real AWS Canary Deployment Test Complete!"
echo ""
echo "Next steps:"
echo "- Monitor CloudWatch alarms"
echo "- Run: ./scripts/promote-canary.sh 50 $STAGE (increase to 50%)"
echo "- Run: ./scripts/promote-canary.sh 100 $STAGE (full promotion)"
echo "- Run: ./scripts/rollback.sh $STAGE (if issues)"