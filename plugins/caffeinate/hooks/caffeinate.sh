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
    # Use fork+setsid to place caffeinate in a new session and process group,
    # fully detaching it from the hook runner's process tree.
    perl -MPOSIX=setsid -e '
        defined(my $pid = fork) or exit 1;
        if ($pid) {
            open my $f, ">", $ARGV[0] and do { print $f $pid; close $f };
            exit 0;
        }
        setsid;
        open STDIN, "<", "/dev/null";
        open STDOUT, ">", "/dev/null";
        open STDERR, ">", "/dev/null";
        exec "/usr/bin/caffeinate", "-di";
    ' "$PIDFILE" 2>/dev/null
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
