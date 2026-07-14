// Default theme — a neutral, professional baseline. Deliberately brand-agnostic.
//
// A "brand" is a partial dictionary deep-merged over this one (see
// ../assets/brand.template.typ and the markdown-to-pdf skill). Override only the keys
// you care about; everything else falls back to the values here.
//
// All fonts referenced here are bundled with Typst, so the default renders with no font
// installation required.

#let default-theme = (
  palette: (
    text:            rgb("#1f2933"),  // near-black slate
    muted:           rgb("#64748b"),  // secondary text / footers
    heading:         rgb("#1f2933"),  // h1
    heading-sub:     rgb("#334155"),  // h2/h3
    accent:          rgb("#2563eb"),  // title rule, small flourishes (neutral blue)
    rule:            rgb("#cbd5e1"),  // hairlines
    link:            rgb("#2563eb"),
    quote-bar:       rgb("#94a3b8"),
    quote-bg:        rgb("#f1f5f9"),
    quote-text:      rgb("#334155"),
    code-bg:         rgb("#f4f5f7"),
    code-text:       rgb("#1f2933"),
    table-head-bg:   rgb("#e7ebf0"),
    table-head-text: rgb("#1f2933"),
    table-stripe:    rgb("#f7f9fb"),
    table-rule:      rgb("#cbd5e1"),
  ),

  fonts: (
    body:    ("Libertinus Serif",),   // bundled
    heading: ("Libertinus Serif",),   // bundled; brands often override to a sans
    mono:    ("DejaVu Sans Mono",),   // bundled
  ),

  sizes: (
    body:  10.5pt,
    h1:    19pt,
    h2:    14.5pt,
    h3:    12pt,
    small: 8.5pt,
    code:  9pt,
  ),

  // Body paragraphs. Ragged-right (justify: false) avoids stretched word-spacing,
  // especially around inline code; with hyphenate: false words never split. Both are
  // overridable per document via frontmatter `justify:` / `hyphenate:`. Headings and the
  // title never hyphenate regardless.
  paragraph: (
    justify:   false,
    hyphenate: false,
  ),

  page: (
    paper:         "us-letter",
    margin:        (x: 1in, y: 1in),
    numbering:     none,             // set e.g. "1" or "1 / 1" to show page numbers
    number-align:  right,            // horizontal placement of the number in the footer
  ),

  // Logo shown in the page header. `none` = no logo. A brand sets, e.g.:
  //   logo: (light: "logo.png", dark: "logo-white.png", height: 0.32in, align: right)
  logo: none,

  title-block: (
    enabled:   true,   // render a title block from frontmatter
    rule:      true,   // accent rule under the title
    align:     left,
  ),

  // Confidentiality levels, keyed by the frontmatter `classification:` value.
  // Each entry: (label: shown text, color: accent, footer: extra footer line or none).
  // Empty by default — the neutral plugin ships no classifications.
  classifications: (:),

  // Static footer line shown on every page regardless of classification (or none).
  footer-note: none,

  // Admonition/callout styling by kind — GitHub-style alerts:
  // `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`.
  callouts: (
    note:      (color: rgb("#1b6bb5"), title: "Note"),
    tip:       (color: rgb("#1a7f37"), title: "Tip"),
    important: (color: rgb("#8250df"), title: "Important"),
    warning:   (color: rgb("#9a6700"), title: "Warning"),
    caution:   (color: rgb("#c84a3b"), title: "Caution"),
  ),
)
