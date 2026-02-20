#!/bin/bash
# caffeinate.sh - Prevent macOS sleep/lock during Claude's active turn.
# Supports multiple concurrent sessions via session-specific PID files.
#
# Fail-open: never blocks Claude operations.
#
# Usage: caffeinate.sh start | stop
# Reads hook JSON from stdin to extract session_id.
#
# Flags: -d (prevent display sleep / lock) -i (prevent idle sleep)

# macOS only
[[ "$(uname)" == "Darwin" ]] || exit 0

PIDDIR="${TMPDIR:-/tmp}"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','default'))" 2>/dev/null || echo "default")
PIDFILE="${PIDDIR}/claude-caffeinate-${SESSION_ID}.pid"

start() {
    stop
    /usr/bin/caffeinate -di >/dev/null 2>&1 &
    disown $! 2>/dev/null
    echo $! > "$PIDFILE" 2>/dev/null
}

stop() {
    if [ -f "$PIDFILE" ]; then
        pid=$(<"$PIDFILE")
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PIDFILE" 2>/dev/null
    fi
}

case "${1:-}" in
    start) start ;;
    stop)  stop ;;
esac

exit 0
