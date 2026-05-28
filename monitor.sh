monitor.sh는 agent-app 프로세스와 15034 포트 상태를 확인하고, CPU/메모리/디스크 사용률을 수집하여 /var/log/agent-app/monitor.log에 기록하는 Bash 모니터링 스크립트입니다.



#!/bin/bash

AGENT_HOME="${AGENT_HOME:-/home/agent-admin/agent-app}"
AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="$AGENT_LOG_DIR/monitor.log"

APP_NAME="agent-app"
MAX_SIZE=$((10 * 1024 * 1024))
MAX_FILES=10

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

rotate_logs() {
  if [ -f "$LOG_FILE" ]; then
    size=$(stat -c%s "$LOG_FILE")
    if [ "$size" -ge "$MAX_SIZE" ]; then
      i=$MAX_FILES
      while [ "$i" -ge 1 ]; do
        if [ -f "$LOG_FILE.$i" ]; then
          if [ "$i" -eq "$MAX_FILES" ]; then
            rm -f "$LOG_FILE.$i"
          else
            mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
          fi
        fi
        i=$((i - 1))
      done
      mv "$LOG_FILE" "$LOG_FILE.1"
    fi
  fi
}

PID=$(pgrep -u agent-admin -f "$AGENT_HOME/$APP_NAME" | head -n 1)

if [ -z "$PID" ]; then
  echo "[$(timestamp)] [ERROR] Process $APP_NAME is not running"
  exit 1
fi

if ! ss -tuln | grep -q ":$AGENT_PORT "; then
  echo "[$(timestamp)] [ERROR] TCP port $AGENT_PORT is not LISTEN"
  exit 1
fi

if command -v ufw >/dev/null 2>&1; then
  if ! systemctl is-active ufw >/dev/null 2>&1; then
    echo "[$(timestamp)] [WARNING] UFW firewall is inactive"
  fi
elif command -v firewall-cmd >/dev/null 2>&1; then
  if ! firewall-cmd --state 2>/dev/null | grep -q "running"; then
    echo "[$(timestamp)] [WARNING] firewalld is inactive"
  fi
else
  echo "[$(timestamp)] [WARNING] No supported firewall tool found"
fi

CPU=$(top -bn1 | awk -F',' '/Cpu\(s\)/ {print 100 - $4}' | awk '{printf "%.1f", $1}')
MEM=$(free | awk '/Mem:/ {printf "%.1f", ($3/$2)*100}')
DISK_USED=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')

if awk -v value="$CPU" 'BEGIN { exit !(value > 20) }'; then
  echo "[$(timestamp)] [WARNING] CPU usage is high: ${CPU}%"
fi

if awk -v value="$MEM" 'BEGIN { exit !(value > 10) }'; then
  echo "[$(timestamp)] [WARNING] Memory usage is high: ${MEM}%"
fi

if [ "$DISK_USED" -gt 80 ]; then
  echo "[$(timestamp)] [WARNING] Disk usage is high: ${DISK_USED}%"
fi

rotate_logs

echo "[$(timestamp)] PID:$PID CPU:${CPU}% MEM:${MEM}% DISK_USED:${DISK_USED}%" >> "$LOG_FILE"
