#!/bin/bash

# Monitor multi-runtime canary deployment metrics
# Usage: ./scripts/monitor-runtime-canary.sh [stage] [duration]

set -e

# Default values
STAGE=${1:-prod}
DURATION=${2:-300}  # 5 minutes
REGION=${AWS_REGION:-us-east-1}

echo "📊 Monitoring multi-runtime canary deployment..."
echo "   Stage: $STAGE"
echo "   Duration: ${DURATION}s"
echo "   Region: $REGION"
echo ""

# Check dependencies
command -v aws >/dev/null 2>&1 || { echo "❌ Error: aws CLI is required but not installed."; exit 1; }

# Get API Gateway and function information
echo "🔍 Getting deployment information..."
API_ID=$(aws cloudformation describe-stacks \
  --stack-name "canary-aws-ping-multi-${STAGE}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayRestApiId`].OutputValue' \
  --output text \
  --region "$REGION")

STABLE_FUNCTION_NAME="ping-stable-${STAGE}"
CANARY_FUNCTION_NAME="ping-canary-${STAGE}"

if [ -z "$API_ID" ]; then
  echo "❌ Error: Could not find API Gateway ID from CloudFormation stack"
  exit 1
fi

echo "📋 API Gateway ID: $API_ID"
echo "📋 Stable Function: $STABLE_FUNCTION_NAME (Node 18)"
echo "📋 Canary Function: $CANARY_FUNCTION_NAME (Node 22)"

# Get current canary settings
CANARY_SETTINGS=$(aws apigateway get-stage \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE" \
  --query 'canarySettings' \
  --output json \
  --region "$REGION")

if [ "$CANARY_SETTINGS" != "null" ] && [ -n "$CANARY_SETTINGS" ]; then
  CANARY_PERCENT=$(echo "$CANARY_SETTINGS" | jq -r '.percentTraffic // 0')
  echo "📊 Current canary: ${CANARY_PERCENT}% traffic to Node 22"
else
  echo "📊 No active canary deployment (100% Node 18)"
  CANARY_PERCENT=0
fi

echo ""

# Function to get metric value
get_metric() {
  local function_name="$1"
  local metric_name="$2"
  local statistic="$3"
  local start_time=$(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%S)
  local end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
  
  aws cloudwatch get-metric-statistics \
    --namespace "AWS/Lambda" \
    --metric-name "$metric_name" \
    --dimensions "Name=FunctionName,Value=$function_name" \
    --start-time "$start_time" \
    --end-time "$end_time" \
    --period 60 \
    --statistics "$statistic" \
    --query 'Datapoints[0].${statistic}' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "0"
}

# Function to check alarm state
check_alarm() {
  local alarm_name="$1"
  
  aws cloudwatch describe-alarms \
    --alarm-names "$alarm_name" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "INSUFFICIENT_DATA"
}

# Monitor for specified duration
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))

echo "⏰ Monitoring started at $(date)"
echo "   Will monitor until $(date -d @$END_TIME)"
echo ""

while [ $(date +%s) -lt $END_TIME ]; do
  # Get metrics for both functions
  STABLE_INVOCATIONS=$(get_metric "$STABLE_FUNCTION_NAME" "Invocations" "Sum")
  STABLE_ERRORS=$(get_metric "$STABLE_FUNCTION_NAME" "Errors" "Sum")
  STABLE_DURATION=$(get_metric "$STABLE_FUNCTION_NAME" "Duration" "Average")
  
  CANARY_INVOCATIONS=$(get_metric "$CANARY_FUNCTION_NAME" "Invocations" "Sum")
  CANARY_ERRORS=$(get_metric "$CANARY_FUNCTION_NAME" "Errors" "Sum")
  CANARY_DURATION=$(get_metric "$CANARY_FUNCTION_NAME" "Duration" "Average")
  
  # Calculate error rates
  if [ "$STABLE_INVOCATIONS" != "0" ] && [ "$STABLE_INVOCATIONS" != "" ]; then
    STABLE_ERROR_RATE=$(echo "scale=2; $STABLE_ERRORS * 100 / $STABLE_INVOCATIONS" | bc -l 2>/dev/null || echo "0")
  else
    STABLE_ERROR_RATE="0"
  fi
  
  if [ "$CANARY_INVOCATIONS" != "0" ] && [ "$CANARY_INVOCATIONS" != "" ]; then
    CANARY_ERROR_RATE=$(echo "scale=2; $CANARY_ERRORS * 100 / $CANARY_INVOCATIONS" | bc -l 2>/dev/null || echo "0")
  else
    CANARY_ERROR_RATE="0"
  fi
  
  # Check alarm states
  STABLE_ERROR_ALARM=$(check_alarm "canary-aws-ping-multi-${STAGE}-stable-errors")
  STABLE_LATENCY_ALARM=$(check_alarm "canary-aws-ping-multi-${STAGE}-stable-latency")
  CANARY_ERROR_ALARM=$(check_alarm "canary-aws-ping-multi-${STAGE}-canary-errors")
  CANARY_LATENCY_ALARM=$(check_alarm "canary-aws-ping-multi-${STAGE}-canary-latency")
  
  # Display current status
  echo "📈 $(date '+%H:%M:%S') - Multi-Runtime Metrics (last 5 minutes):"
  echo ""
  echo "   🏠 STABLE (Node 18):"
  echo "      Invocations: $STABLE_INVOCATIONS"
  echo "      Errors: $STABLE_ERRORS (${STABLE_ERROR_RATE}%)"
  echo "      Avg Duration: ${STABLE_DURATION}ms"
  echo "      Error Alarm: $STABLE_ERROR_ALARM"
  echo "      Latency Alarm: $STABLE_LATENCY_ALARM"
  echo ""
  echo "   🐤 CANARY (Node 22):"
  echo "      Invocations: $CANARY_INVOCATIONS"
  echo "      Errors: $CANARY_ERRORS (${CANARY_ERROR_RATE}%)"
  echo "      Avg Duration: ${CANARY_DURATION}ms"
  echo "      Error Alarm: $CANARY_ERROR_ALARM"
  echo "      Latency Alarm: $CANARY_LATENCY_ALARM"
  echo ""
  
  # Check if any alarms are triggered
  if [ "$STABLE_ERROR_ALARM" = "ALARM" ] || [ "$STABLE_LATENCY_ALARM" = "ALARM" ] || \
     [ "$CANARY_ERROR_ALARM" = "ALARM" ] || [ "$CANARY_LATENCY_ALARM" = "ALARM" ]; then
    echo "🚨 ALARM TRIGGERED! Consider rolling back."
    echo "   Run: ./scripts/rollback-runtime-canary.sh $STAGE"
    break
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  sleep 30
done

echo "✅ Monitoring completed at $(date)"

# Final summary
echo ""
echo "🎯 Final Status Summary:"
if [ "$CANARY_PERCENT" -gt 0 ]; then
  echo "   Traffic Split: $((100 - CANARY_PERCENT))% Node 18, ${CANARY_PERCENT}% Node 22"
else
  echo "   Traffic: 100% Node 18 (no canary active)"
fi
echo "   Stable Runtime: Node 18 - $STABLE_INVOCATIONS invocations, ${STABLE_ERROR_RATE}% errors"
echo "   Canary Runtime: Node 22 - $CANARY_INVOCATIONS invocations, ${CANARY_ERROR_RATE}% errors"