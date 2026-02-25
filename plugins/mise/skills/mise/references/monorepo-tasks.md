# mise Monorepo Tasks

## When to Use This Reference

- Organizing tasks across multiple packages/services in a monorepo
- Decomposing a flat root-level taskfile into per-component definitions
- Running the same task across multiple packages
- Layering tool versions per package while sharing common configuration

**Note:** Monorepo tasks are experimental. Requires `MISE_EXPERIMENTAL=1` environment variable.

## Quick Reference

| Syntax | Meaning |
|--------|---------|
| `//path/to/pkg:task` | Absolute task reference from root |
| `:task` | Task in current config root (from subdirectory) |
| `//...:task` | Run `task` in all packages |
| `//services/...:task` | Run `task` in all packages under `services/` |
| `//path/to/pkg:*` | All tasks in a specific package |

## The Rule

Monorepo mode lets each package define its own tasks in its own `mise.toml`. Tasks are automatically namespaced by their directory path. The root `mise.toml` defines shared infrastructure; package `mise.toml` files define package-specific work.

This replaces the pattern of a single large taskfile at the root that knows about every package. Instead, task definitions live next to the code they operate on.

## Setup

Enable in the root `mise.toml`:

```toml
# mise.toml (project root)
experimental_monorepo_root = true

[monorepo]
config_roots = [
    "crates/*",
    "services/*",
    "packages/frontend",
]
```

Export the experimental flag in your shell or `.mise.toml`:
```bash
export MISE_EXPERIMENTAL=1
```

`config_roots` uses single-level globs to discover package directories. This avoids filesystem walking — mise only looks where you tell it.

## Patterns

### Directory Structure

```
myproject/
├── mise.toml                    # Root: shared tools, CI orchestration
├── crates/
│   ├── core/
│   │   └── mise.toml            # Package: build, test, lint
│   └── api/
│       └── mise.toml            # Package: build, test, run
├── services/
│   └── worker/
│       └── mise.toml            # Package: build, deploy
└── packages/
    └── frontend/
        └── mise.toml            # Package: dev, build, lint
```

### Root-Level Orchestration Tasks

The root defines tasks that span packages:

```toml
# mise.toml (root)
experimental_monorepo_root = true

[monorepo]
config_roots = ["crates/*", "services/*", "packages/*"]

[tools]
rust = "latest"
node = "lts"

[tasks.ci]
depends = ["lint", "test"]
description = "Run full CI pipeline"

[tasks.lint]
run = "cargo clippy --workspace -- -D warnings"

[tasks.test]
run = "cargo nextest run --workspace"
```

### Package-Level Task Definitions

Each package defines tasks that operate on its own code:

```toml
# services/worker/mise.toml
[tasks.build]
run = "cargo build -p worker --release"
sources = ["src/**/*.rs", "Cargo.toml"]
outputs = ["../../target/release/worker"]

[tasks.deploy]
run = "flyctl deploy"
depends = ["build"]
tools = { "aqua:flyctl" = "latest" }
confirm = "Deploy worker to production?"

[tasks.dev]
run = "cargo watch -p worker -x run"
tools = { "cargo:cargo-watch" = "latest" }
```

### Running Tasks

From the project root:
```bash
# Run a specific package's task
mise //services/worker:build
mise //packages/frontend:dev

# Run the same task across all packages
mise '//...:test'

# Run all tasks under a directory
mise '//crates/...:lint'

# Run all tasks in a specific package
mise '//services/worker:*'
```

From a package directory:
```bash
cd services/worker
mise :build           # Explicit: run this package's build
mise build            # Also works (resolves to local config root)
```

### Tool Version Layering

Child config files inherit from parents and can override:

```toml
# mise.toml (root)
[tools]
node = "22"

[env]
LOG_LEVEL = "info"
```

```toml
# packages/frontend/mise.toml
[tools]
node = "20"           # Override: this package needs Node 20

[env]
LOG_LEVEL = "debug"   # Override for local dev
PORT = "3000"         # Additional variable
```

Precedence (highest wins): task-specific `tools`/`env` > package `mise.toml` > root `mise.toml` > global config.

### Task Templates for Consistent Patterns

Define reusable task shapes at the root that packages extend:

```toml
# mise.toml (root)
[task_templates."rust:build"]
run = "cargo build -p {{config_root | basename}} --release"
sources = ["src/**/*.rs", "Cargo.toml"]

[task_templates."rust:test"]
run = "cargo nextest run -p {{config_root | basename}}"
sources = ["src/**/*.rs", "tests/**/*.rs"]
tools = { "cargo:cargo-nextest" = "latest" }
```

```toml
# crates/core/mise.toml
[tasks.build]
extends = "rust:build"

[tasks.test]
extends = "rust:test"
```

Templates keep package `mise.toml` files minimal while ensuring consistent patterns.

### Cross-Package Dependencies

Package tasks can depend on tasks from other packages:

```toml
# services/worker/mise.toml
[tasks.build]
run = "cargo build -p worker --release"
depends = ["//crates/core:build"]
```

### Pattern: Decomposing a Flat Taskfile

**Before:** A single root taskfile that knows about every component:
```toml
# Everything in one place — hard to maintain as the project grows
[tasks."worker:build"]
run = "cargo build -p worker --release"
[tasks."worker:deploy"]
run = "flyctl deploy --config services/worker/fly.toml"
[tasks."frontend:build"]
run = "npm --prefix packages/frontend run build"
[tasks."frontend:dev"]
run = "npm --prefix packages/frontend run dev"
```

**After:** Each component owns its tasks:
```toml
# services/worker/mise.toml
[tasks.build]
run = "cargo build -p worker --release"
[tasks.deploy]
run = "flyctl deploy"
tools = { "aqua:flyctl" = "latest" }
```

```toml
# packages/frontend/mise.toml
[tasks.build]
run = "npm run build"
[tasks.dev]
run = "npm run dev"
```

The root `mise.toml` becomes an orchestrator, not an encyclopedia:
```toml
# mise.toml (root)
experimental_monorepo_root = true
[monorepo]
config_roots = ["services/*", "packages/*"]

[tasks.ci]
depends = ["lint", "//...:test"]
```

Benefits:
- Adding a new package doesn't touch the root config
- Task definitions live next to the code they build
- `flyctl` only installs for developers who run the worker deploy task
- `mise '//...:test'` discovers and runs all package tests automatically

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Missing `MISE_EXPERIMENTAL=1` | Monorepo features silently ignored | Export env var or set in mise config |
| Missing `experimental_monorepo_root` | Tasks not discovered | Add to root `mise.toml` |
| No `config_roots` defined | Only root tasks visible | Explicitly list package directories |
| Using `mise run task` from root | Ambiguous if multiple packages define it | Use `mise //path:task` absolute syntax |
| All tasks in root `mise.toml` | Root grows unmanageable | Move package tasks to package `mise.toml` |

## Resources

- [Monorepo Tasks](https://mise.jdx.dev/tasks/monorepo.html)
- [Tasks Overview](https://mise.jdx.dev/tasks/)
- [Task Configuration](https://mise.jdx.dev/tasks/task-configuration.html)
