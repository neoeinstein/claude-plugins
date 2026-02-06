# mise Configuration

## When to Use This Reference

- Setting up mise.toml for a new project
- Understanding config file precedence
- Configuring tool versions and sources
- Using mise.local.toml for personal overrides

## Quick Reference

| File | Purpose | Committed? |
|------|---------|------------|
| `mise.toml` | Project toolchain | Yes |
| `mise.local.toml` | Personal overrides | No |
| `.mise.toml` | Alternative name | Yes |
| `~/.config/mise/config.toml` | Global defaults | N/A |

## The Rule

mise reads configuration files in order of specificity. More specific files override less specific ones. `mise.local.toml` always wins for local overrides.

## Patterns

### Basic mise.toml

```toml
[tools]
rust = "latest"
node = "lts"
python = "3.12"

[env]
DATABASE_URL = "postgres://localhost/dev"
```

### Tool with Options

```toml
[tools]
rust = { version = "latest", components = "clippy,rustfmt" }
node = { version = "20", global = false }
```

### Cargo-Installed Tools

```toml
[tools]
"cargo:cargo-nextest" = "latest"
"cargo:cargo-watch" = "0.8"
```

### npm-Installed Tools

```toml
[tools]
"npm:typescript" = "latest"
"npm:eslint" = "8"
```

### Configuration Precedence

From highest to lowest priority:

1. `mise.local.toml` — Personal overrides (gitignored)
2. `mise.toml` — Project configuration
3. `.mise.toml` — Alternative project location
4. `mise/config.toml` — Subdirectory alternative
5. `~/.config/mise/config.toml` — Global defaults

### mise.local.toml for Contributors

When contributing to a project without mise or with different tools:

```toml
# mise.local.toml - NOT committed
[tools]
rust-analyzer = "latest"
"cargo:bacon" = "latest"
```

Add to global gitignore:
```bash
git config --global core.excludesFile ~/.gitignore_global
echo "mise.local.toml" >> ~/.gitignore_global
```

### Environment Variables

```toml
[env]
# Static value
API_KEY = "dev-key"

# From file
DATABASE_URL = { file = ".env.local" }

# Template with other values
RUST_LOG = "{{env.RUST_LOG_LEVEL}},myapp=debug"
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Committing `mise.local.toml` | Personal config in repo | Add to `.gitignore` |
| Using `.tool-versions` format | Limited features | Migrate to `mise.toml` |
| Overriding team tools in `mise.toml` | Conflicts with team | Use `mise.local.toml` |
| Missing tool source prefix | Tool not found | Use `cargo:`, `npm:`, etc. |

## Resources

- [Configuration Reference](https://mise.jdx.dev/configuration.html)
- [Settings](https://mise.jdx.dev/configuration/settings.html)
- [Environment Variables](https://mise.jdx.dev/environments/)
