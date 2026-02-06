# mise Task Runner

## When to Use This Reference

- Defining build, test, or dev tasks in mise.toml
- Setting up task dependencies
- Using watch mode for auto-rebuild
- Running tasks with specific environment

## Quick Reference

| Command | Purpose |
|---------|---------|
| `mise run <task>` | Run a task |
| `mise run` | List available tasks |
| `mise watch` | Run tasks on file change |
| `mise run <task> -- args` | Pass arguments to task |

## The Rule

mise tasks replace Makefile, npm scripts, and shell scripts. Define them in `mise.toml` or as files in `mise-tasks/` directory.

## Patterns

### Basic Task

```toml
[tasks.build]
run = "cargo build --release"
description = "Build release binary"
```

### Task with Dependencies

```toml
[tasks.test]
run = "cargo test"
depends = ["build"]

[tasks.ci]
depends = ["lint", "test", "build"]
```

### Task with Environment

```toml
[tasks.dev]
run = "cargo run"
env = { RUST_LOG = "debug" }
```

### Multi-Command Task

```toml
[tasks.setup]
run = """
mise install
cargo build
npm install
"""
```

### File-Based Tasks

Create executable files in `mise-tasks/`:

```bash
# mise-tasks/deploy
#!/bin/bash
set -e
cargo build --release
rsync -av target/release/myapp server:/opt/
```

Benefits: Real syntax highlighting, linting, shellcheck.

### Watch Mode

```toml
[tasks.dev]
run = "cargo run"
sources = ["src/**/*.rs"]
```

Run with:
```bash
mise watch -t dev
```

Rebuilds when source files change.

### Confirmation for Destructive Tasks

```toml
[tasks.deploy-prod]
run = "./deploy.sh production"
confirm = "Deploy to PRODUCTION?"
```

### Task Arguments

```toml
[tasks.test]
run = "cargo test"
```

```bash
# Pass arguments after --
mise run test -- --nocapture
# Runs: cargo test --nocapture
```

### Available Environment Variables

Inside tasks:
- `MISE_ORIGINAL_CWD` — Directory where mise was invoked
- `MISE_CONFIG_ROOT` — Directory containing mise.toml
- `MISE_PROJECT_ROOT` — Project root
- `MISE_TASK_NAME` — Current task name

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Circular dependencies | Task hangs or errors | Check `depends` for cycles |
| Task not found | "No such task" | Check task name, run `mise run` to list |
| Watch not triggering | No rebuild on save | Check `sources` pattern matches files |
| Arguments not passed | Args ignored | Use `--` before arguments |

## Resources

- [Tasks Overview](https://mise.jdx.dev/tasks/)
- [Task Configuration](https://mise.jdx.dev/tasks/task-configuration.html)
- [Running Tasks](https://mise.jdx.dev/tasks/running-tasks.html)
