# neoeinstein-plugins

A Claude Code plugin marketplace containing development-focused plugins.

## Installation

Add this marketplace to Claude Code:

```
/plugin marketplace add neoeinstein/claude-plugins
```

Then browse and install individual plugins:

```
/plugin browse
/plugin install rust-best-practices@neoeinstein-plugins
```

## Available Plugins

| Plugin | Version | Description |
|--------|---------|-------------|
| **rust-best-practices** | 1.0.0 | Idiomatic Rust development guidance with best practices skill and auto-formatting hook |
| **askama** | 0.1.0 | Askama Rust template engine guidance for writing and debugging templates |
| **htmx-alpine** | 0.1.0 | HTMX and Alpine.js patterns for server-driven web applications |
| **mise** | 0.1.0 | mise toolchain manager guidance for consistent development environments |
| **typst** | 0.2.0 | Typst authoring skill + a markdown-to-pdf workflow: Markdown → branded PDF/HTML via a pure Typst pipeline |

## Repository Structure

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace catalog
├── plugins/
│   ├── rust-best-practices/      # Rust development skill + rustfmt hook
│   ├── askama/                   # Askama template guidance
│   ├── htmx-alpine/             # HTMX + Alpine.js patterns
│   ├── mise/                    # mise toolchain management
│   └── typst/                   # Typst authoring skill + markdown-to-pdf workflow
└── README.md
```

Each plugin has its own `.claude-plugin/plugin.json` manifest and contains skills, hooks, or both.

## Plugin Details

### rust-best-practices

The primary plugin. Provides:
- A comprehensive best-practices skill covering error handling, type safety, async patterns, unsafe code, testing, and more
- An auto-formatting hook that runs `rustfmt` after file edits, with nightly/stable toolchain fallback

### askama

Template engine guidance for Askama (Jinja2-like templates compiled to Rust). Covers writing templates and debugging compilation errors.

### htmx-alpine

Patterns for building server-driven web applications with HTMX and Alpine.js. Language-agnostic guidance focused on the interaction model.

### mise

Guidance for using mise as a toolchain manager. Covers both `mise.toml` (for repos you control) and `mise.local.toml` (for repos you contribute to).

### typst

Bundles two skills: a comprehensive **Typst** authoring reference (vendored from
[lucifer1004/claude-skill-typst](https://github.com/lucifer1004/claude-skill-typst), MIT) and a
**markdown-to-pdf** workflow that converts Markdown to branded PDF or HTML through a pure Typst
pipeline (cmarker + a themeable document engine). Branding is pluggable per project or per user
— colors, fonts, logo, page numbers, and confidentiality footers — via a `brand.typ` override
the plugin can scaffold.

## License

MIT
