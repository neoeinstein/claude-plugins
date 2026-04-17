---
description: Convert a Markdown file to a styled PDF using pandoc + XeLaTeX
allowed-tools: Bash, Glob
argument-hint: "[file or description]"
---

# markdown-to-pdf

Convert a Markdown file to PDF.

## Resolving the target file

Arguments: "$ARGUMENTS"

1. If `$ARGUMENTS` is empty — look at recent conversation context for a `.md` file that was being discussed or edited. If one is obvious, use it. If ambiguous, ask.
2. If `$ARGUMENTS` looks like a file path (contains `/` or ends in `.md`) — use it directly if it exists; otherwise report not found.
3. Otherwise treat `$ARGUMENTS` as a description. Use Glob to search for `.md` files whose name loosely matches (e.g. `**/*brief*.md`, `**/*$ARGUMENTS*.md`). Pick the best match; if multiple candidates, ask which one.

## Running the conversion

Once the target file is resolved:

```zsh
${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf <resolved-path>
```

If the script exits non-zero, run `${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf --check` and report what's missing.

Report the output path on success.
