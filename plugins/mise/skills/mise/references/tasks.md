# mise Task Runner

## When to Use This Reference

- Defining build, test, or dev tasks in mise.toml
- Setting up task dependencies and lifecycle hooks
- Declaring task-specific tool requirements
- Using incremental builds with sources/outputs
- Running tasks with specific environment
- Using watch mode for auto-rebuild

## Quick Reference

| Command | Purpose |
|---------|---------|
| `mise run <task>` | Run a task |
| `mise run` | Run default task, or list tasks if none |
| `mise watch -t <task>` | Run task on file change |
| `mise run <task> -- args` | Pass arguments to task |
| `mise tasks` | List available tasks |
| `mise tasks deps` | Show task dependency tree |

## The Rule

mise tasks replace Makefile, npm scripts, justfiles, and shell scripts. Define them in `mise.toml` or as files in `mise-tasks/` directory. Tasks run in parallel by default (up to 4 jobs) and support dependency ordering, incremental builds, and task-specific toolchains.

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

Dependencies with arguments or environment:
```toml
[tasks.ci]
depends = [
    "build",
    { task = "test", env = { DATABASE_URL = "postgres://localhost/test" } },
]
```

### Lifecycle Hooks with `depends_post`

Run cleanup or verification after a task completes:

```toml
[tasks.migrate]
run = "sqlx migrate run"
depends_post = ["migrate:verify"]

[tasks."migrate:verify"]
run = "sqlx migrate info"
hide = true
```

### Optional Dependencies with `wait_for`

Wait for a task if it's already running, but don't start it automatically:

```toml
[tasks.test]
run = "cargo test"
wait_for = ["db:seed"]
# If db:seed is running (started by another task), wait for it.
# Otherwise, run immediately without starting db:seed.
```

### Task with Environment

```toml
[tasks.dev]
run = "cargo run"
env = { RUST_LOG = "debug" }
```

### Task-Specific Tools

Declare tools that only this task needs. They're installed on demand, not as project-wide dependencies:

```toml
[tasks.docs]
run = "mdbook build"
tools = { "cargo:mdbook" = "latest" }

[tasks.db-migrate]
run = "sqlx migrate run"
tools = { "cargo:sqlx-cli" = "0.8" }

[tasks.deploy]
run = "flyctl deploy"
tools = { "aqua:flyctl" = "latest" }
```

This keeps project-wide `[tools]` focused on the primary development toolchain. Contributors who never run `mise run deploy` never install `flyctl`.

### Incremental Builds with Sources/Outputs

Skip re-execution when inputs haven't changed:

```toml
[tasks.build]
run = "cargo build --release"
sources = ["Cargo.toml", "Cargo.lock", "src/**/*.rs"]
outputs = ["target/release/myapp"]
```

For tasks without deterministic output files, use automatic tracking:

```toml
[tasks.codegen]
run = "cargo run -p codegen"
sources = ["schemas/**/*.json"]
outputs = { auto = true }
```

### Shared Variables

Share non-environment configuration between tasks:

```toml
[vars]
target_dir = "target/release"
deploy_host = "app.example.com"

[tasks.build]
run = "cargo build --release --target-dir {{vars.target_dir}}"

[tasks.deploy]
run = "rsync -av {{vars.target_dir}}/myapp {{vars.deploy_host}}:/opt/"
depends = ["build"]
```

### Task Composition

Structured `run` arrays mix shell commands with task references:

```toml
[tasks.release]
run = [
    { task = "build" },
    { tasks = ["test", "lint"] },
    "echo 'All checks passed, packaging...'",
    "./scripts/package.sh",
]
```

Tasks in the same array element run in parallel; array elements run sequentially.

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

### Task Arguments with Usage Specs

Define formal arguments for validation, help text, and shell completion:

```toml
[tasks.deploy]
run = "kubectl apply -f deploy/{{arg(name='env')}}"
usage = '''
arg "<env>" help="Target environment" default="staging" {
    choices "staging" "production"
}
'''
confirm = "Deploy to {{arg(name='env')}}?"
```

```bash
mise run deploy staging
mise run deploy production  # Shows confirmation prompt
```

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

### Task Grouping with Namespaces

Use `:` separators to organize related tasks hierarchically:

```toml
[tasks."test:unit"]
run = "cargo nextest run --lib"

[tasks."test:integration"]
run = "cargo nextest run --test '*'"
depends = ["db:reset"]

[tasks."test:all"]
depends = ["test:unit", "test:integration"]

[tasks."db:reset"]
run = "sqlx database reset -y"
tools = { "cargo:sqlx-cli" = "0.8" }

[tasks."db:migrate"]
run = "sqlx migrate run"
tools = { "cargo:sqlx-cli" = "0.8" }
```

Run with wildcards: `mise run 'test:*'` or `mise run 'db:*'`.

### Available Environment Variables

Inside tasks:
- `MISE_ORIGINAL_CWD` — Directory where mise was invoked
- `MISE_CONFIG_ROOT` — Directory containing mise.toml
- `MISE_PROJECT_ROOT` — Project root
- `MISE_TASK_NAME` — Current task name

### Task Arguments (Simple)

```toml
[tasks.test]
run = "cargo test"
```

```bash
# Pass arguments after --
mise run test -- --nocapture
# Runs: cargo test --nocapture
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Circular dependencies | Task hangs or errors | Check `depends` for cycles |
| Task not found | "No such task" | Check task name, run `mise tasks` to list |
| Watch not triggering | No rebuild on save | Check `sources` pattern matches files |
| Arguments not passed | Args ignored | Use `--` before arguments |
| Tool in project `[tools]` only used by one task | Unnecessary install for all devs | Move to `tasks.<name>.tools` |
| Missing `sources` on incremental task | Always re-runs | Add source globs for skip-when-unchanged |

## Resources

- [Tasks Overview](https://mise.jdx.dev/tasks/)
- [Task Configuration](https://mise.jdx.dev/tasks/task-configuration.html)
- [Running Tasks](https://mise.jdx.dev/tasks/running-tasks.html)
