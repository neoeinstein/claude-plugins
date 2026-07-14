---
description: Convert a Markdown file to a styled PDF or HTML page using Typst
allowed-tools: Bash, Glob
argument-hint: "[file or description] [pdf|html]"
---

# markdown-to-pdf

Convert a Markdown file to a styled PDF (or HTML) via the plugin's Typst pipeline.

## Resolving the target file

Arguments: "$ARGUMENTS"

1. If `$ARGUMENTS` is empty — look at recent conversation context for a `.md` file that was
   being discussed or edited. If one is obvious, use it. If ambiguous, ask.
2. If `$ARGUMENTS` looks like a file path (contains `/` or ends in `.md`) — use it directly if
   it exists; otherwise report not found.
3. Otherwise treat `$ARGUMENTS` as a description. Use Glob to find `.md` files whose name
   loosely matches (e.g. `**/*brief*.md`, `**/*$ARGUMENTS*.md`). Pick the best match; if
   several are plausible, ask which one.

If the arguments mention "html", pass `--format html`; otherwise default to PDF.

## Running the conversion

Once the target file is resolved:

```zsh
${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf <resolved-path>
```

**Request unsandboxed access when invoking this script.** It runs `typst compile`, which needs
to write temp + output files and — on first use — download Typst packages over the network.
These operations typically fail under the default Bash sandbox.

Branding is picked up automatically from `.markdown-to-pdf/brand.typ` (project) or
`~/.config/markdown-to-pdf/brand.typ` (user); pass `--brand <path>` to override, or
`--classification <level>` to stamp a confidentiality footer.

If the script exits non-zero, run `${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf --check`
(also unsandboxed) and report what's missing. Do **not** run install commands it prints —
those must be executed by the user directly.

Report the output path on success.
