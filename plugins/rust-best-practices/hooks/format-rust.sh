#!/bin/bash
# PostToolUse hook: Format Rust files with rustfmt after writes.
# Uses nightly rustfmt when rustfmt.toml exists (nightly-only options),
# falls back to stable otherwise.

# This script is designed to be fail-open: it should never block edits.
# We intentionally avoid `set -e` so that any unexpected failure
# falls through to exit 0 rather than blocking the edit operation.

# Extract file path from hook input (JSON on stdin)
file_path=$(jq -r '.tool_input.file_path' 2>/dev/null || echo "")

if [ -z "$file_path" ]; then
  exit 0
fi

# Only format Rust files
if [[ "$file_path" != *.rs ]]; then
  exit 0
fi

# Check if rustfmt is available at all
if ! command -v rustfmt &>/dev/null; then
  exit 0
fi

# Walk up directories from the file to find rustfmt.toml or .rustfmt.toml
find_rustfmt_config() {
  local dir
  dir=$(dirname "$file_path")
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/rustfmt.toml" ] || [ -f "$dir/.rustfmt.toml" ]; then
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

if find_rustfmt_config; then
  # Config found: try nightly (for nightly-only options), fall back to stable
  rustfmt +nightly "$file_path" 2>/dev/null || rustfmt "$file_path" 2>/dev/null || exit 0
else
  # No config: use stable directly
  rustfmt "$file_path" 2>/dev/null || exit 0
fi
