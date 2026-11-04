#!/usr/bin/env bash
# NC2R API supervisor for Linux/macOS. Starts `php artisan serve` and restarts it
# forever if it exits or crashes; only one instance can run at a time.
# Prefer the systemd unit (nc2r-api.service) in production - it also starts at
# boot - but this script works anywhere (cron @reboot, Docker, manual run).
#
# Optional env: NC2R_HOST (default 127.0.0.1), NC2R_PORT (default 8000),
#               PHP_BIN (default php), PHP_CLI_SERVER_WORKERS (default 4)
set -u
cd "$(dirname "$0")/.."

HOST="${NC2R_HOST:-127.0.0.1}"
PORT="${NC2R_PORT:-8000}"
PHP_BIN="${PHP_BIN:-php}"
export PHP_CLI_SERVER_WORKERS="${PHP_CLI_SERVER_WORKERS:-4}"
mkdir -p storage/logs
RLOG="storage/logs/server-restarts.log"

if command -v flock >/dev/null 2>&1; then
    exec 9>storage/nc2r-api.lock
    flock -n 9 || { echo "Another NC2R API supervisor is already running."; exit 0; }
fi

child=0
trap 'kill "$child" 2>/dev/null; wait "$child" 2>/dev/null; exit 0' TERM INT HUP

while true; do
    echo "[$(date '+%F %T')] Starting NC2R API on http://$HOST:$PORT ..."
    "$PHP_BIN" artisan serve --host="$HOST" --port="$PORT" &
    child=$!
    wait "$child"
    code=$?
    echo "[$(date '+%F %T')] Server exited with code $code, restarting in 5s" | tee -a "$RLOG"
    sleep 5 &
    wait $!
done
