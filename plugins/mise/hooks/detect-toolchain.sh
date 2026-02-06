#!/bin/bash
# detect-toolchain.sh - mise detection for Claude Code agent priming
#
# Fail-open: never blocks operations. No `set -e`.
#
# Outputs context for the Claude agent about mise state:
# - Team config: mise.toml, .mise.toml, or .tool-versions
# - Local config: mise.local.toml only (contributor mode)
# - No config: explain what mise is for

# Check for team/committed config first
if [ -f "mise.toml" ] || [ -f ".mise.toml" ] || [ -f ".tool-versions" ]; then
    echo "mise: Project toolchain managed via mise. Runtime versions (node/python/rust) pinned for team consistency — library deps stay in package managers (npm/cargo/pip). Run \`mise install\` after pulling. See mise skill for guidance."
    exit 0
fi

# Check for local-only config (contributor mode)
if [ -f "mise.local.toml" ]; then
    echo "mise: Local toolchain config (mise.local.toml). Runtime versions managed locally, not shared with team. Library deps stay in package managers. If this is your repo, consider mise.toml for team consistency. See mise skill."
    exit 0
fi

# No config found
echo "mise: No toolchain configuration. mise pins runtime versions (node/python/rust) in mise.toml for team consistency — solves \"works on my machine\" for toolchains. Library deps stay in package managers (npm/cargo/pip). Use mise skill if setting up toolchain management."
exit 0
