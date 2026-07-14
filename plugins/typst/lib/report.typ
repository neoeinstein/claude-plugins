// report.typ — the markdown-to-pdf engine.
//
// Renders a Markdown file (via cmarker) into a styled document, driven entirely by a theme
// dictionary. Applied as a document show rule from a generated `main.typ`:
//
//   #import "/abs/path/lib/report.typ": report
//   #show: report.with(source: "/abs/doc.md", doc-dir: "/abs/dir", overrides: brand,
//                      format: "pdf", raw-handlers: (:))
//
// The engine imports NO diagram packages; a caller that wants Mermaid/Graphviz passes render
// functions in `raw-handlers` (e.g. (mermaid: text => ..., dot: text => ...)) so plain docs
// never pull WASM packages.

#import "@preview/cmarker:0.1.10"
#import "@preview/mitex:0.2.7": mitex
#import "../themes/default.typ": default-theme

// ── helpers ──────────────────────────────────────────────────────────────────

// Deep-merge `over` onto `base` (dicts merge recursively; other values are replaced).
#let deep-merge(base, over) = {
  if type(base) == dictionary and type(over) == dictionary {
    let out = base
    for (k, v) in over {
      out.insert(k, if k in base { deep-merge(base.at(k), v) } else { v })
    }
    out
  } else { over }
}

// Normalize a frontmatter author value to an array of strings.
#let _authors(v) = {
  if v == none { () }
  else if type(v) == array { v.map(str) }
  else { (str(v),) }
}

// Resolve a classification name against the theme's `classifications` map.
#let _classification(theme, name) = {
  if name == none or str(name).trim() == "" { return none }
  let key = str(name)
  if key in theme.classifications { theme.classifications.at(key) }
  else { (label: key, color: theme.palette.muted, footer: none) }
}

// ── admonitions / callouts ────────────────────────────────────────────────────

// Rewrite GitHub-style alert blockquotes — `> [!NOTE]` and friends — into a `mtpcallout`
// call injected via cmarker's raw-typst. The body stays Markdown (cmarker renders it); the
// marker line is consumed. Non-alert blockquotes pass through untouched.
#let _preprocess-admonitions(md) = {
  let lines = md.split("\n")
  let out = ()
  let i = 0
  while i < lines.len() {
    let m = lines.at(i).match(regex("^> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$"))
    if m != none {
      let kind = lower(m.captures.at(0))
      let body = ()
      i += 1
      while i < lines.len() and lines.at(i).starts-with(">") {
        body.push(lines.at(i).replace(regex("^>[ ]?"), ""))
        i += 1
      }
      out.push("<!--raw-typst #mtpcallout(\"" + kind + "\")[-->")
      out.push(body.join("\n"))
      out.push("<!--raw-typst ]-->")
    } else {
      out.push(lines.at(i))
      i += 1
    }
  }
  out.join("\n")
}

#let _render-callout(kind, body, theme) = {
  let fallback = (color: theme.palette.quote-bar, title: upper(kind.slice(0, 1)) + kind.slice(1))
  let c = theme.callouts.at(kind, default: fallback)
  block(
    width: 100%, inset: (x: 12pt, y: 9pt), radius: 3pt, above: 1em, below: 1em,
    fill: c.color.lighten(88%),
    stroke: (left: 3pt + c.color),
    {
      text(fill: c.color, weight: "bold")[#c.title]
      parbreak()
      body
    },
  )
}

// ── frontmatter + math ────────────────────────────────────────────────────────

// Split a leading `---` YAML frontmatter block off the Markdown. Returns (meta, body).
// Parsed here (not via cmarker) so the math setting is known before rendering.
#let _split-frontmatter(md) = {
  let lines = md.split("\n")
  if lines.len() == 0 or lines.at(0).trim() != "---" { return ((:), md) }
  let close = none
  let i = 1
  while i < lines.len() {
    if lines.at(i).trim() == "---" { close = i; break }
    i += 1
  }
  if close == none { return ((:), md) }
  let front = lines.slice(1, close).join("\n")
  let body = if close + 1 < lines.len() { lines.slice(close + 1).join("\n") } else { "" }
  let meta = if front.trim() == "" { (:) } else { yaml(bytes(front)) }
  if type(meta) != dictionary { meta = (:) }
  (meta, body)
}

// A ```math fenced block → centered display equation via mitex. Unambiguous (unlike $…$),
// so it is always enabled.
#let _render-math-block(src) = block(
  width: 100%, above: 0.9em, below: 0.9em,
  align(center, mitex(src)),
)

// Detect real inline `$…$` math in a code-free text segment and inject it into mitex, while
// leaving currency ($) and shell vars ($PATH, $PATH=$HOME) alone. A span converts only when
// ALL hold: it opens/closes on a non-space char (Pandoc rule), the char after the closing `$`
// is not a digit (so `$5 and $10` is safe), and the body contains a LaTeX signal char
// (\ ^ _ { }) — which separates `$E=mc^2$` from `$3.2K` and `$PATH=$HOME`. `\$` is protected
// via a sentinel so escapes stay literal.
#let _math-replace(seg) = {
  let sentinel = "\u{E000}"
  let s = seg.replace("\\$", sentinel)
  s = s.replace(regex("\\$([^\\s$](?:[^$\n]*?[^\\s$])?)\\$"), m => {
    let body = m.captures.at(0)
    let next-is-digit = s.slice(m.end).match(regex("^[0-9]")) != none
    // math if the body carries a LaTeX token (\ ^ _ { }) OR is a short 1-2 char identifier
    // (x, n, dx) — the latter lets simple variables render while long tokens ($PATH$, $HOME$)
    // and shell assignments ($FOO=$BAR) stay literal.
    let is-math = body.contains(regex("[\\\\^_{}]")) or body.match(regex("^[A-Za-z][A-Za-z0-9]?$")) != none
    if (not next-is-digit) and is-math {
      "<!--raw-typst #mitex(block: false, \"" + body.replace("\\", "\\\\").replace("\"", "\\\"") + "\")-->"
    } else {
      m.text
    }
  })
  s.replace(sentinel, "\\$")
}

// Apply _math-replace to a line, skipping inline `code` spans verbatim.
#let _process-line-math(line) = {
  let spans = line.matches(regex("`[^`]*`"))
  if spans.len() == 0 { return _math-replace(line) }
  let out = ""
  let idx = 0
  for cs in spans {
    out += _math-replace(line.slice(idx, cs.start)) + line.slice(cs.start, cs.end)
    idx = cs.end
  }
  out + _math-replace(line.slice(idx))
}

// Currency/code-safe inline-math pass over the whole document, skipping fenced code blocks.
#let _extract-inline-math(md) = {
  let out = ()
  let in-fence = false
  for line in md.split("\n") {
    if line.trim().match(regex("^(```+|~~~+)")) != none {
      in-fence = not in-fence
      out.push(line)
    } else if in-fence {
      out.push(line)
    } else {
      out.push(_process-line-math(line))
    }
  }
  out.join("\n")
}

// ── title block ──────────────────────────────────────────────────────────────

#let _title-block(meta, theme, paged) = {
  let pal = theme.palette
  let f = theme.fonts
  let has = (k) => k in meta and meta.at(k) != none and str(meta.at(k)).trim() != ""

  if not (has("title") or has("subtitle")) { return }

  set text(hyphenate: false)   // titles break at word boundaries, never mid-word
  set align(theme.title-block.align)
  block(below: 1.2em, {
    if has("title") {
      block(below: 0.7em,
        text(font: f.heading, size: theme.sizes.h1 * 1.15, weight: "bold", fill: pal.heading)[#meta.title])
    }
    if has("subtitle") {
      block(below: 0.45em,
        text(font: f.heading, size: theme.sizes.h2, fill: pal.heading-sub)[#meta.subtitle])
    }
    // byline: authors · date
    let by = _authors(meta.at("author", default: none))
    let date = if has("date") { (str(meta.date),) } else { () }
    let bits = by + date
    if bits.len() > 0 {
      block(text(size: theme.sizes.small, fill: pal.muted)[#bits.join("  ·  ")])
    }
    // accent rule (paged only — line() has no HTML equivalent)
    if theme.title-block.rule and paged {
      v(0.45em)
      line(length: 100%, stroke: 1.2pt + pal.accent)
    }
  })
}

// ── footer / header ────────────────────────────────────────────────────────

#let _footer(theme, cls) = {
  let pal = theme.palette
  let has-num = theme.page.numbering != none
  let note = {
    let parts = ()
    if theme.footer-note != none { parts.push(theme.footer-note) }
    if cls != none and cls.footer != none { parts.push(cls.footer) }
    if parts.len() > 0 { parts.join("  ·  ") } else { none }
  }
  // nothing to show → no footer at all (avoids a bare hairline)
  if not (has-num or note != none or cls != none) { return none }

  context {
    let cell-left = if cls != none { text(fill: cls.color, weight: "medium")[#cls.label] } else { none }
    let cell-right = if has-num { counter(page).display(theme.page.numbering) } else { none }
    set text(size: theme.sizes.small, fill: pal.muted)
    block(width: 100%, {
      line(length: 100%, stroke: 0.5pt + pal.rule)
      v(0.4em)
      grid(
        columns: (1fr, auto, 1fr),
        align: (left + horizon, center + horizon, right + horizon),
        cell-left, note, cell-right,
      )
    })
  }
}

#let _header(theme, brand-dir) = {
  let logo = theme.logo
  if logo == none { return none }
  let src = logo.at("light", default: logo.at("dark", default: none))
  if src == none { return none }
  if not src.starts-with("/") { src = brand-dir + "/" + src }
  let h = logo.at("height", default: 0.32in)
  let a = logo.at("align", default: right)
  context {
    set align(a)
    box(image(src, height: h))
  }
}

// ── the engine ───────────────────────────────────────────────────────────────

#let report(
  body,
  source: none,
  doc-dir: ".",
  brand-dir: ".",
  overrides: (:),
  format: "pdf",
  classification: none,
  raw-handlers: (:),
) = {
  let theme = deep-merge(default-theme, overrides)
  let pal = theme.palette
  let f = theme.fonts
  let s = theme.sizes
  let paged = format != "html"

  // resolve relative image paths against the source document's directory
  let img = (src, ..a) => {
    let p = if src.starts-with("/") { src } else { doc-dir + "/" + src }
    image(p, ..a)
  }

  let (meta, body-raw) = _split-frontmatter(if source != none { read(source) } else { "" })
  // Inline $…$ math is detected by our own currency/code-safe scanner (not cmarker's, which
  // eats currency); ```math handles display. cmarker's own math is off (math: none).
  let body-md = _extract-inline-math(_preprocess-admonitions(body-raw))
  let mdbody = cmarker.render(
    body-md,
    smart-punctuation: true,
    scope: (
      image: img,
      mtpcallout: (kind, body) => _render-callout(kind, body, theme),
      mitex: mitex,
    ),
    math: none,
  )

  let cls-name = if classification != none { classification } else {
    meta.at("classification", default: none)
  }
  let cls = _classification(theme, cls-name)

  // paragraph justify + hyphenation: theme default, overridable per document
  let just = theme.paragraph.at("justify", default: false)
  let hyph = theme.paragraph.at("hyphenate", default: false)
  if type(meta.at("justify", default: none)) == bool { just = meta.justify }
  if type(meta.at("hyphenate", default: none)) == bool { hyph = meta.hyphenate }

  // ── document + text ──
  set document(
    title: meta.at("title", default: none),
    author: _authors(meta.at("author", default: none)),
  )
  set text(font: f.body, size: s.body, fill: pal.text, hyphenate: hyph)
  set par(justify: just, leading: 0.62em, spacing: 0.95em)

  // ── page furniture (paged output only) ──
  set page(
    paper: theme.page.paper,
    margin: theme.page.margin,
    numbering: theme.page.numbering,
    header: _header(theme, brand-dir),
    header-ascent: 40%,
    footer: _footer(theme, cls),
    footer-descent: 30%,
  ) if format != "html"

  // ── headings: keep the element (semantic HTML), restyle text ──
  set heading(numbering: none)
  show heading: set text(font: f.heading, weight: "bold", hyphenate: false)
  show heading.where(level: 1): set text(fill: pal.heading, size: s.h1)
  show heading.where(level: 2): set text(fill: pal.heading-sub, size: s.h2)
  show heading.where(level: 3): set text(fill: pal.heading-sub, size: s.h3)
  show heading: it => block(above: 0.95em, below: 0.4em, it)

  // ── links ──
  show link: set text(fill: pal.link)

  // ── inline + block code ──
  show raw.where(block: false): it => box(
    fill: pal.code-bg, inset: (x: 3pt), outset: (y: 3pt), radius: 2pt,
    text(font: f.mono, fill: pal.code-text)[#it],
  )
  show raw.where(block: true): it => block(
    fill: pal.code-bg, inset: 9pt, radius: 4pt, width: 100%,
    text(font: f.mono, size: s.code, fill: pal.code-text)[#it],
  )

  // ── blockquotes: left accent bar + tint ──
  show quote.where(block: true): it => block(
    width: 100%, fill: pal.quote-bg, inset: (x: 12pt, y: 8pt),
    stroke: (left: 3pt + pal.quote-bar),
  )[#set text(fill: pal.quote-text); #it.body]

  // ── tables: header fill + zebra, hairline rules ──
  set table(
    inset: (x: 8pt, y: 5pt),
    align: left + horizon,
    stroke: (x, y) => (bottom: 0.5pt + pal.table-rule),
    fill: (x, y) => if y == 0 { pal.table-head-bg }
      else if calc.even(y) { pal.table-stripe } else { none },
  )
  show table.cell.where(y: 0): set text(fill: pal.table-head-text, weight: "bold")

  // ── ```math fenced block → display equation (always on) ──
  show raw.where(lang: "math"): it => _render-math-block(it.text)

  // ── diagram interception (no-op unless a handler is supplied) ──
  show raw.where(lang: "mermaid"): it => if "mermaid" in raw-handlers {
    (raw-handlers.mermaid)(it.text)
  } else { it }
  show raw.where(lang: "dot"): it => if "dot" in raw-handlers {
    (raw-handlers.dot)(it.text)
  } else { it }
  show raw.where(lang: "graphviz"): it => if "graphviz" in raw-handlers {
    (raw-handlers.graphviz)(it.text)
  } else { it }

  // ── content ──
  if theme.title-block.enabled { _title-block(meta, theme, paged) }
  mdbody
  body
}
