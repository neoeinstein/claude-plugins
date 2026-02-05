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

## Repository Structure

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace catalog
├── plugins/
│   ├── rust-best-practices/      # Rust development skill + rustfmt hook
│   ├── askama/                   # Askama template guidance
│   ├── htmx-alpine/             # HTMX + Alpine.js patterns
│   └── mise/                    # mise toolchain management
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

## License

MIT
