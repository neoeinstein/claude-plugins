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

Booleans `justify` and `hyphenate` also work here to override paragraph style for one document.

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

## Gotchas

- **Errors** → run `--check` (typst version, package reachability, brand resolution); report
  what's missing rather than installing it yourself.
- **Image paths** resolve against the document's directory; a brand's `logo` path against
  `brand.typ`.
- **HTML** export is experimental (prints a disclaimer); page headers/footers are omitted.
- **Math** (`$…$`) needs a handler (`mitex`), off by default — ask before adding the dependency.
