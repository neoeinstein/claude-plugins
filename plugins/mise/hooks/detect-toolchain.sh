#!/bin/bash
# detect-toolchain.sh - Minimal mise detection for Claude Code
#
# This script is designed to be fail-open: it should never block operations.
# We intentionally avoid `set -e` so that any unexpected failure
# falls through to exit 0 rather than blocking the session.
#
# Behavior:
# - Silent if mise.toml exists (project already configured)
# - Single-line suggestion if no mise.toml found
# - Only fires once per project (creates marker file)

# Get the project root (where Claude Code is running)
PROJECT_ROOT="${PWD}"

# Marker file to prevent repeated suggestions
MARKER_DIR="${PROJECT_ROOT}/.mise"
MARKER_FILE="${MARKER_DIR}/.detected"

# Check if we've already run for this project
if [ -f "${MARKER_FILE}" ]; then
    exit 0
fi

# Check for existing mise configuration
if [ -f "${PROJECT_ROOT}/mise.toml" ] || \
   [ -f "${PROJECT_ROOT}/.mise.toml" ] || \
   [ -f "${PROJECT_ROOT}/.tool-versions" ] || \
   [ -f "${PROJECT_ROOT}/mise.lock" ]; then
    # Project already has mise config, create marker and exit silently
    mkdir -p "${MARKER_DIR}" 2>/dev/null || true
    touch "${MARKER_FILE}" 2>/dev/null || true
    exit 0
fi

# No mise config found - suggest initialization
# Create marker first so we don't repeat
mkdir -p "${MARKER_DIR}" 2>/dev/null || true
touch "${MARKER_FILE}" 2>/dev/null || true

# Output suggestion (single line, non-intrusive)
echo "mise: No mise.toml found. Run \`mise use rust@latest\` or \`mise use node@lts\` to initialize toolchain."

# Always exit successfully
exit 0
