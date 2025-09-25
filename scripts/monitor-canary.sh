#!/bin/bash

# Monitor canary deployment metrics and alarms
# Usage: ./scripts/monitor-canary.sh [stage] [duration]

set -e

# Default values
STAGE=${1:-prod}
DURATION=${2:-300}  # 5 minutes
REGION=${AWS_REGION:-us-east-1}
FUNCTION_NAME="canary-aws-ping-$STAGE-ping"

echo "📊 Monitoring canary deployment..."
echo "   Stage: $STAGE"
echo "   Function: $FUNCTION_NAME"
echo "   Duration: ${DURATION}s"
echo "   Region: $REGION"
echo ""

# Function to get metric value
get_metric() {
  local metric_name="$1"
  local statistic="$2"
  local start_time=$(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%S)
  local end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
  
  aws cloudwatch get-metric-statistics \
    --namespace "AWS/Lambda" \
    --metric-name "$metric_name" \
    --dimensions "Name=FunctionName,Value=$FUNCTION_NAME" \
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
  # Get current metrics
  INVOCATIONS=$(get_metric "Invocations" "Sum")
  ERRORS=$(get_metric "Errors" "Sum")
  DURATION_AVG=$(get_metric "Duration" "Average")
  THROTTLES=$(get_metric "Throttles" "Sum")
  
  # Calculate error rate
  if [ "$INVOCATIONS" != "0" ] && [ "$INVOCATIONS" != "" ]; then
    ERROR_RATE=$(echo "scale=2; $ERRORS * 100 / $INVOCATIONS" | bc -l 2>/dev/null || echo "0")
  else
    ERROR_RATE="0"
  fi
  
  # Check alarm states
  ERROR_ALARM_STATE=$(check_alarm "AliasErrorMetricGreaterThanThresholdAlarm")
  LATENCY_ALARM_STATE=$(check_alarm "AliasLatencyMetricGreaterThanThresholdAlarm")
  
  # Display current status
  echo "📈 $(date '+%H:%M:%S') - Metrics (last 5 minutes):"
  echo "   Invocations: $INVOCATIONS"
  echo "   Errors: $ERRORS (${ERROR_RATE}%)"
  echo "   Avg Duration: ${DURATION_AVG}ms"
  echo "   Throttles: $THROTTLES"
  echo "   Error Alarm: $ERROR_ALARM_STATE"
  echo "   Latency Alarm: $LATENCY_ALARM_STATE"
  
  # Check if alarms are triggered
  if [ "$ERROR_ALARM_STATE" = "ALARM" ] || [ "$LATENCY_ALARM_STATE" = "ALARM" ]; then
    echo "🚨 ALARM TRIGGERED! Consider rolling back."
    echo "   Run: ./scripts/rollback.sh $STAGE"
    break
  fi
  
  echo ""
  sleep 30
done

echo "✅ Monitoring completed at $(date)"