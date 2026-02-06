#!/bin/bash
# detect-toolchain.sh - Minimal mise detection for Claude Code
#
# Fail-open: never blocks operations. No `set -e`.
#
# Behavior:
# - Silent if mise config exists
# - Brief note if no config found (primes agent, doesn't prescribe action)

# Check for existing mise configuration
if [ -f "mise.toml" ] || \
   [ -f ".mise.toml" ] || \
   [ -f ".tool-versions" ] || \
   [ -f "mise.lock" ]; then
    exit 0
fi

echo "mise: No toolchain configuration detected. The mise skill can help if needed."
exit 0
