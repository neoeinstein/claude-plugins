// Brand override for markdown-to-pdf.
//
// This file customizes the look of PDFs/HTML produced by the `typst` plugin's
// markdown-to-pdf workflow. It exports a single dictionary named `brand` that is
// deep-merged over the plugin's neutral default theme — so you only set the keys you
// want to change; everything else falls back to the default.
//
// Resolution order (first found wins):
//   1. ./.markdown-to-pdf/brand.typ   (project-local)
//   2. ~/.config/markdown-to-pdf/brand.typ   (user-global)
// Override explicitly with:  markdown-to-pdf --brand /path/to/brand.typ doc.md
//
// After editing, sanity-check it compiles:
//   markdown-to-pdf --check
//
// Everything below is optional. Delete what you don't need; the commented blocks show
// the full set of knobs.

#let brand = (
  // ── Colors ────────────────────────────────────────────────────────────────
  // Any subset of the palette. Values are Typst colors: rgb("#RRGGBB").
  palette: (
    heading:     rgb("#1a2b45"),   // h1 + title
    heading-sub: rgb("#33475b"),   // h2 / h3 / subtitle
    accent:      rgb("#c26a1b"),   // title rule + flourishes
    link:        rgb("#1b6bb5"),
    // text:        rgb("#22272e"),
    // muted:       rgb("#5b6472"),
    // quote-bar:   rgb("#c26a1b"),
    // quote-bg:    rgb("#f6efe6"),
    // code-bg:     rgb("#f3f4f6"),
    // table-head-bg:   rgb("#e9edf2"),
    // table-head-text: rgb("#1a2b45"),
    // table-stripe:    rgb("#f7f9fb"),
    // table-rule:      rgb("#cbd5e1"),
  ),

  // ── Fonts ─────────────────────────────────────────────────────────────────
  // Provide a fallback list; the first installed family wins. Defaults are
  // Typst-bundled (Libertinus Serif / DejaVu Sans Mono), so overriding is optional.
  // fonts: (
  //   body:    ("Georgia", "Libertinus Serif"),
  //   heading: ("Arial", "Helvetica Neue"),
  //   mono:    ("JetBrains Mono", "DejaVu Sans Mono"),
  // ),

  // ── Page geometry + numbering ───────────────────────────────────────────────
  page: (
    numbering: "1",                // show page numbers; e.g. "1" or "1 / 1". Omit / none = off.
    // paper:  "us-letter",        // or "a4"
    // margin: (x: 1in, y: 1in),
  ),

  // ── Logo (page header) ──────────────────────────────────────────────────────
  // Paths are relative to THIS brand.typ file. Provide a light-background variant
  // (used on the white page) and optionally a dark one.
  // logo: (
  //   light:  "logo.png",
  //   dark:   "logo-white.png",
  //   height: 0.32in,
  //   align:  right,              // left | center | right
  // ),

  // ── Confidentiality footer ──────────────────────────────────────────────────
  // Keyed by the document's frontmatter `classification:` value (or the
  // `--classification` flag). Each entry sets the footer label + color, and an
  // optional extra footer line.
  // classifications: (
  //   "Public":       (label: "Public",       color: rgb("#5b6472"), footer: none),
  //   "Internal":     (label: "Internal",     color: rgb("#1b6bb5"),
  //                    footer: "Internal use only — do not distribute externally."),
  //   "Confidential": (label: "Confidential", color: rgb("#b23b2e"),
  //                    footer: "Confidential — authorized recipients only."),
  // ),

  // ── Static footer line (all pages, any classification) ──────────────────────
  // footer-note: "ACME, Inc.",
)
