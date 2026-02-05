---
name: mise
description: Use when setting up development toolchains with mise, managing tool versions, or configuring project environments - covers both mise.toml for repos you control and mise.local.toml for repos you contribute to
---

# mise Toolchain Management

## Overview

mise manages development tool versions and environment configuration. Use it to ensure consistent toolchains across team members and CI.

**Core principle:** Two modes of operation — `mise.toml` for repos you control (committed to git), `mise.local.toml` for repos you contribute to (gitignored, personal config).

## Quick Reference

| Scenario | Config File | Committed? |
|----------|------------|------------|
| Your project, team-wide tools | `mise.toml` | Yes |
| Contributing to someone else's repo | `mise.local.toml` | No (gitignored) |
| User-wide defaults | `~/.config/mise/config.toml` | N/A |

## When to Use Each

### mise.toml — Repos You Control

Committed to git. Defines the project's required toolchain for all contributors:

```toml
[tools]
rust = { version = "latest", components = "clippy,rustfmt" }
"cargo:cargo-nextest" = "latest"
node = "lts"
```

Use when:
- Setting up a new project's toolchain
- Adding tools the whole team needs
- Pinning versions for reproducibility

### mise.local.toml — Repos You Contribute To

Not committed (add to `.gitignore`). Your personal tool preferences for a project that doesn't use mise or uses different tools:

```toml
[tools]
rust-analyzer = "latest"
"cargo:cargo-watch" = "latest"
```

Use when:
- The repo doesn't have a `mise.toml`
- You want additional tools beyond what the team requires
- You need different versions than what's pinned

## Common Tool Configurations

### Rust Projects

```toml
[tools]
rust = { version = "latest", components = "clippy,rustfmt", targets = "wasm32-unknown-unknown" }
"cargo:cargo-nextest" = "latest"
rust-analyzer = "latest"
```

### Python Projects

```toml
[tools]
python = "latest"
ruff = "latest"
uv = "latest"
```

### Node.js Projects

```toml
[tools]
node = "lts"
npm = "latest"
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Committing `mise.local.toml` | Add to `.gitignore` |
| Using `mise.local.toml` in your own repo | Use `mise.toml` — let contributors benefit |
| Forgetting to run `mise install` after cloning | Add to project setup docs or README |
| Pinning exact versions when `latest` is fine | Use `latest` for tools where latest is always compatible |
