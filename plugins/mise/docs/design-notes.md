# mise Plugin - Design Notes

## Current State (v0.1.0)

Stub skill covering the two primary usage modes: `mise.toml` for repos you control and `mise.local.toml` for repos you contribute to. Includes common tool configurations for Rust, Python, and Node.js projects.

## Future Design Scope

### Hook Exploration
- SessionStart hook to detect project toolchain and inject context
- Auto-detect when `mise.toml` exists and remind about `mise install`
- Potentially suggest tools based on detected project type (Cargo.toml -> Rust tools)

### Toolchain Detection
- Detect project type from files (Cargo.toml, package.json, pyproject.toml, etc.)
- Suggest appropriate mise.toml configurations based on detected stack
- Warn when common tools are missing (e.g., Rust project without cargo-nextest)

### Advanced mise Features
- Task runner (`[tasks]` section)
- Environment variables (`[env]` section)
- mise plugins and backends
- `.tool-versions` compatibility for projects using asdf
- CI integration patterns (GitHub Actions, GitLab CI)

### Cross-Plugin Integration
- Coordinate with rust-best-practices plugin (suggest Rust toolchain config)
- Coordinate with htmx-alpine plugin (suggest Node.js toolchain for frontend)
