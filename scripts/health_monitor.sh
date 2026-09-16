#!/usr/bin/env bash
# ==============================================================================
# Linux Health Check Daemon & Latency Shipper
# Continuously monitors Cloud Run service health, measures microsecond latency,
# and outputs structured JSON logs.
# ==============================================================================
set -euo pipefail

# Configuration defaults
SERVICE_URL="${1:-http://localhost:8080/health}"
LOG_FILE="${LOG_FILE:-/tmp/service_health.log}"
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-5}"
LATENCY_THRESHOLD_SEC="${LATENCY_THRESHOLD_SEC:-1.5}"
RUN_ONCE="${RUN_ONCE:-false}"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Graceful termination handler
cleanup() {
    echo -e "\n[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Health monitor daemon received termination signal. Exiting gracefully..."
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "================================================================="
echo " Starting Linux Health Monitor Daemon"
echo " Target URL:       $SERVICE_URL"
echo " Log Destination:  $LOG_FILE"
echo " Interval:         ${CHECK_INTERVAL_SEC}s"
echo " Alert Threshold:  ${LATENCY_THRESHOLD_SEC}s"
echo "================================================================="

perform_check() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Use curl with high-resolution timing metrics
    local curl_format="%{http_code}:%{time_namelookup}:%{time_connect}:%{time_starttransfer}:%{time_total}"
    local curl_output
    
    curl_output=$(curl -s -o /dev/null -w "$curl_format" \
        --max-time 10 \
        -H "User-Agent: Linux-Health-Daemon/1.0" \
        "$SERVICE_URL" 2>/dev/null || echo "000:0:0:0:0")

    IFS=':' read -r status_code dns_time connect_time ttfb_time total_time <<< "$curl_output"

    local is_healthy=false
    if [ "$status_code" -ge 200 ] && [ "$status_code" -lt 300 ]; then
        is_healthy=true
    fi

    # Check for latency degradation
    local latency_degraded=false
    if (( $(echo "$total_time > $LATENCY_THRESHOLD_SEC" | bc -l 2>/dev/null || echo 0) )); then
        latency_degraded=true
    fi

    # Construct structured JSON log payload
    local json_payload
    json_payload=$(cat <<EOF
{"timestamp":"$timestamp","service_url":"$SERVICE_URL","status_code":$status_code,"healthy":$is_healthy,"latency_degraded":$latency_degraded,"metrics":{"dns_sec":$dns_time,"connect_sec":$connect_time,"ttfb_sec":$ttfb_time,"total_sec":$total_time}}
EOF
)

    # Append to log file and stdout
    echo "$json_payload" >> "$LOG_FILE"
    echo "$json_payload"

    # Alert condition
    if [ "$is_healthy" != "true" ]; then
        echo "[ALERT] Service unhealthy at $timestamp! HTTP Status: $status_code. Target: $SERVICE_URL" >&2
    elif [ "$latency_degraded" == "true" ]; then
        echo "[WARNING] Latency degradation detected: ${total_time}s exceeds threshold of ${LATENCY_THRESHOLD_SEC}s" >&2
    fi
}

# Execution mode: single run or daemon loop
if [ "$RUN_ONCE" == "true" ] || [ "${2:-}" == "--once" ]; then
    perform_check
    exit 0
fi

while true; do
    perform_check
    sleep "$CHECK_INTERVAL_SEC"
done
