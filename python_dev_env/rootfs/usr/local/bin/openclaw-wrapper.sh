#!/bin/bash
# OpenClaw Port Conflict Resolver Wrapper
# Kills any existing processes using port 18789 before starting openclaw

PORT=18789

# Find and kill any processes using the port
echo "[openclaw-wrapper] Checking for processes using port $PORT..."

# Try to find PIDs using the port
PIDS=$(lsof -t -i :$PORT 2>/dev/null || ss -tlnp 2>/dev/null | grep ":$PORT" | grep -oP 'pid=\K[0-9]+' || netstat -tlnp 2>/dev/null | grep ":$PORT" | awk '{print $7}' | cut -d'/' -f1 | grep -E '^[0-9]+$')

if [ -n "$PIDS" ]; then
    echo "[openclaw-wrapper] Found processes using port $PORT: $PIDS"
    for PID in $PIDS; do
        if [ -n "$PID" ] && [ "$PID" -ne "$$" ]; then
            echo "[openclaw-wrapper] Killing process $PID..."
            kill -9 "$PID" 2>/dev/null || true
        fi
    done
    sleep 1
    echo "[openclaw-wrapper] Port $PORT cleared"
else
    echo "[openclaw-wrapper] Port $PORT is free"
fi

# Also kill any existing openclaw-gateway processes
OPENCLAW_PIDS=$(pgrep -f "openclaw-gateway" 2>/dev/null || echo "")
if [ -n "$OPENCLAW_PIDS" ]; then
    echo "[openclaw-wrapper] Killing existing openclaw-gateway processes: $OPENCLAW_PIDS"
    echo "$OPENCLAW_PIDS" | xargs -r kill -9 2>/dev/null || true
    sleep 1
fi

# Wait a moment for port to be fully released
sleep 1

echo "[openclaw-wrapper] Starting openclaw..."
exec /opt/nvm/versions/node/v24.14.0/bin/openclaw gateway --port $PORT "$@"