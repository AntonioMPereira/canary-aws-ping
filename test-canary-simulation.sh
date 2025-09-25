#!/bin/bash

# Canary Deployment Test Simulator
# Simulates traffic splitting between stable (1.0.0) and canary (1.0.1) versions

set -e

echo "🧪 Canary Deployment Test Simulator"
echo "=================================="
echo ""

# Configuration
TOTAL_REQUESTS=20
CANARY_WEIGHT=10  # 10% traffic to canary
STABLE_RESPONSES=0
CANARY_RESPONSES=0

echo "📊 Test Configuration:"
echo "   Total Requests: $TOTAL_REQUESTS"
echo "   Canary Weight: $CANARY_WEIGHT%"
echo "   Stable Weight: $((100 - CANARY_WEIGHT))%"
echo ""

# Function to simulate version response
simulate_version_response() {
    local version=$1
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    local request_id=$(openssl rand -hex 16)
    
    cat << EOF
{
  "message": "ping v20.19.4",
  "timestamp": "$timestamp",
  "version": "$version",
  "environment": "prod",
  "requestId": "$request_id"
}
EOF
}

echo "🚀 Starting canary traffic simulation..."
echo ""

# Simulate requests with traffic splitting
for i in $(seq 1 $TOTAL_REQUESTS); do
    # Generate random number 1-100
    RANDOM_NUM=$((RANDOM % 100 + 1))
    
    if [ $RANDOM_NUM -le $CANARY_WEIGHT ]; then
        # Route to CANARY (1.0.1)
        echo "Request $i → 🐤 CANARY v1.0.1"
        simulate_version_response "1.0.1" | jq -c .
        CANARY_RESPONSES=$((CANARY_RESPONSES + 1))
    else
        # Route to STABLE (1.0.0)  
        echo "Request $i → 🏠 STABLE v1.0.0"
        simulate_version_response "1.0.0" | jq -c .
        STABLE_RESPONSES=$((STABLE_RESPONSES + 1))
    fi
    
    sleep 0.5
done

echo ""
echo "📈 Traffic Distribution Results:"
echo "================================"
echo "🏠 Stable v1.0.0: $STABLE_RESPONSES requests ($((STABLE_RESPONSES * 100 / TOTAL_REQUESTS))%)"
echo "🐤 Canary v1.0.1: $CANARY_RESPONSES requests ($((CANARY_RESPONSES * 100 / TOTAL_REQUESTS))%)"
echo ""

# Validate distribution is approximately correct
EXPECTED_CANARY=$((TOTAL_REQUESTS * CANARY_WEIGHT / 100))
TOLERANCE=2

if [ $CANARY_RESPONSES -ge $((EXPECTED_CANARY - TOLERANCE)) ] && [ $CANARY_RESPONSES -le $((EXPECTED_CANARY + TOLERANCE)) ]; then
    echo "✅ Traffic distribution is within expected range!"
    echo "   Expected canary: ~$EXPECTED_CANARY requests"
    echo "   Actual canary: $CANARY_RESPONSES requests"
else
    echo "⚠️  Traffic distribution outside expected range"
    echo "   Expected canary: ~$EXPECTED_CANARY requests"  
    echo "   Actual canary: $CANARY_RESPONSES requests"
fi

echo ""
echo "🎯 Canary Deployment Simulation Complete!"