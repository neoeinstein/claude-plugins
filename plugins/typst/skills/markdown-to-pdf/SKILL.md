---
name: markdown-to-pdf
description: Use when converting a Markdown file to a styled PDF or HTML page — a pure Typst pipeline (cmarker + a themeable engine) with pluggable branding: colors, fonts, logo, page numbers, confidentiality footers. Requires zsh + the typst CLI.
---

# markdown-to-pdf

Converts a Markdown file to a styled **PDF or HTML** via Typst — no pandoc or LaTeX.
Requires `zsh` and the `typst` CLI (`brew install typst`); Typst auto-downloads the packages
it needs on first run, then works offline.

## Usage

```zsh
${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf <input.md> [output]      # → input.pdf
${CLAUDE_PLUGIN_ROOT}/scripts/markdown-to-pdf --format html <input.md> # → input.html
```

Other flags: `--brand <path>`, `--classification <level>`, `--init-brand [--global]`,
`--check`. Run with `--help` for the full list.

**Invoke unsandboxed** — `typst compile` writes temp/output files and fetches packages on
first run, which the default Bash sandbox blocks.

## Frontmatter

Optional YAML sets per-document metadata (title block + `classification` lookup):

```yaml
---
title: Quarterly Review
subtitle: Reliability and cost
author: [Marcus Griep, Platform Team]
date: 2026-07-14
classification: Confidential
---
```

Booleans `justify` and `hyphenate` also work here. `brand:` selects a brand kit for the
document — a bare name (resolved to
`~/.config/markdown-to-pdf/brands/<name>/brand.typ`) or a path (relative to the doc, or
absolute). The `--brand` flag overrides it.

## Branding

A `brand.typ` exporting `#let brand = (...)` — a partial dict deep-merged over the default
theme — overrides `palette`, `fonts`, `page` (incl. `numbering`), `paragraph`
(`justify`/`hyphenate`), `logo`, `classifications`, and `footer-note`. Resolution, unless `--brand` is given: project `.markdown-to-pdf/brand.typ`
→ `~/.config/markdown-to-pdf/brand.typ`.

`--init-brand [--global]` scaffolds a commented starter — **that file documents every key.**
Authoring it is plain Typst; load the **`typst` skill** (same plugin) for the language.

## Diagrams

Fenced ` ```mermaid `, ` ```dot `, and ` ```graphviz ` blocks render as diagrams (WASM, no
external tools), fetched only when used. Other languages stay syntax-highlighted code.

## Callouts

GitHub-style alerts render as colored callouts: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`,
`> [!WARNING]`, `> [!CAUTION]`. Their colors and titles are theme-configurable (`callouts`).

## Math

Inline `$…$` auto-renders (via mitex) when the body carries a LaTeX token (`\ ^ _ { }`) or is a
short variable (`$x$`, `$dx$`, `$p_{99}$`). Currency (`$3.2K`), env vars (`$PATH`, `$PATH=$HOME`),
long tokens (`$HOME$`), and `$` inside code stay literal. Use a ` ```math ` fenced block for
display equations. Escape `\$` to force a literal that would otherwise render.

## Gotchas

- **Errors** → run `--check` (typst version, package reachability, brand resolution); report
  what's missing rather than installing it yourself.
- **Image paths** resolve against the document's directory; a brand's `logo` path against
  `brand.typ`.
- **HTML** export is experimental (prints a disclaimer); page headers/footers are omitted.
- **Math** — inline `$…$` converts only with a LaTeX token or a short variable (see Math);
  currency, `$PATH`, and code `$` stay literal. Use ` ```math ` for display; escape `\$` to force
  a literal.
- **Tildes** — a lone `~` (e.g. `~16%`, `~$1K`) is kept literal; `~~text~~` is strikethrough.
