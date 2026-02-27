#!/usr/bin/env bash
# Detects pipeline evaluator configuration at session start.
# Outputs context for the agent about available evaluators.
# Fail-open: never blocks Claude operations.

set -o pipefail

EVALUATOR_DIR=".claude/pipeline-evaluators"

# Check if we're in a project with pipeline evaluator config
if [ ! -d "$EVALUATOR_DIR" ]; then
  exit 0
fi

# Count custom evaluators (exclude config.md)
custom_count=0
custom_names=""
for f in "$EVALUATOR_DIR"/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  [ "$name" = "config" ] && continue
  custom_count=$((custom_count + 1))
  if [ -n "$custom_names" ]; then
    custom_names="$custom_names, $name"
  else
    custom_names="$name"
  fi
done

# Extract language from config frontmatter if present
language=""
if [ -f "$EVALUATOR_DIR/config.md" ]; then
  language=$(sed -n '/^---$/,/^---$/{ /^language:/{ s/^language: *//; p; } }' "$EVALUATOR_DIR/config.md" 2>/dev/null)
fi

# Build output message
msg="pipeline-evaluators: Project has custom evaluator config"
if [ -n "$language" ]; then
  msg="$msg (language: $language)"
fi
if [ "$custom_count" -gt 0 ]; then
  msg="$msg with $custom_count custom evaluator(s): $custom_names"
fi
msg="$msg. Use the orchestrate-pipeline skill for multi-agent development."

echo "$msg"
exit 0
