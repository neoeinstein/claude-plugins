---
name: markdown-to-pdf
description: Use when converting a Markdown file to a styled PDF — invokes the plugin converter. macOS only.
---

# markdown-to-pdf

Converts Markdown files to polished PDFs using pandoc + XeLaTeX. Produces navy-colored heading hierarchy, styled blockquotes, smart table column widths, and optional diagram rendering from code blocks.

**macOS only.** Requires zsh. Not supported on Windows or Linux.

## Usage

```zsh
${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf <input.md> [output.pdf]
```

If `output.pdf` is omitted, the PDF is written alongside the source file with the same name.

```zsh
# Generate alongside source
${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf briefs/my-doc.md

# Specify output path
${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf briefs/my-doc.md exports/my-doc.pdf

# Override monofont
MONOFONT="JetBrains Mono" ${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf briefs/my-doc.md
```

## Common Issues

**Any error on startup** — run `${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf --check` for a full diagnostic with versions and install hints for everything missing.

**Diagram block silently skipped** — the renderer for that diagram type isn't installed. Run `--check` to see which are present.

**`Command \underbar has changed`** — LaTeX package warning from texlive. Cosmetic only, does not affect output.
