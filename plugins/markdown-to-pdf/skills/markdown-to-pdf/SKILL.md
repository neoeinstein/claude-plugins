---
name: markdown-to-pdf
description: Use when converting a Markdown file to a styled PDF — checks prerequisites, sets up the script if missing, and invokes the converter. macOS only.
---

# markdown-to-pdf

Converts Markdown files to polished PDFs using pandoc + XeLaTeX. Produces navy-colored heading hierarchy, styled blockquotes, smart table column widths, and optional diagram rendering from code blocks.

**macOS only.** Requires zsh. Not supported on Windows or Linux.

## Script Setup

Check if the script exists in the project:

```zsh
test -f scripts/markdown-to-pdf && echo "exists" || echo "missing"
```

If missing, copy it from the plugin cache:

```zsh
PLUGIN_SCRIPTS=$(find ~/.claude/plugins/cache/neoeinstein-plugins/markdown-to-pdf -name 'markdown-to-pdf' -type f | head -1 | xargs dirname)
cp "$PLUGIN_SCRIPTS/markdown-to-pdf" scripts/markdown-to-pdf
cp "$PLUGIN_SCRIPTS/diagram.lua" scripts/diagram.lua
chmod +x scripts/markdown-to-pdf
```

## Usage

```
scripts/markdown-to-pdf <input.md> [output.pdf]
```

If `output.pdf` is omitted, the PDF is written alongside the source file with the same name.

```zsh
# Generate alongside source
scripts/markdown-to-pdf briefs/my-doc.md

# Specify output path
scripts/markdown-to-pdf briefs/my-doc.md exports/my-doc.pdf

# Override monofont
MONOFONT="JetBrains Mono" scripts/markdown-to-pdf briefs/my-doc.md
```

Always execute directly (do not prefix with `bash` or `zsh` — the shebang handles it).

## Common Issues

**Any error on startup** — run `scripts/markdown-to-pdf --check` to get a full diagnostic with versions and install hints for everything missing.

**Diagram block silently skipped** — the renderer for that diagram type isn't installed. Run `--check` to see which are present.

**`Command \underbar has changed`** — LaTeX package warning from texlive. Cosmetic only, does not affect output.
