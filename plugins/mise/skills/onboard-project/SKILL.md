---
name: onboard-project
description: Use when adopting mise for an existing project — detects current toolchain files and task runners, presents migration options, and generates mise.toml configuration
user-invocable: true
---

# Onboard Project to mise

## Overview

Guided workflow for adopting mise in an existing project. Detects what's already configured, presents migration options, and generates `mise.toml` based on your choices.

**Core principle:** Detect first, then present options — don't assume full migration is the goal.

## Workflow

### Phase 1: Detection

Scan the project for existing configuration. Report findings before proposing changes.

**Toolchain files to detect:**

| File | Tool | Notes |
|------|------|-------|
| `.nvmrc` | nvm (Node) | Single version string |
| `.node-version` | nodenv/fnm | Single version string |
| `.python-version` | pyenv | Single version string |
| `.ruby-version` | rbenv | Single version string |
| `.java-version` | jenv | Single version string |
| `.tool-versions` | asdf | Multi-tool, mise reads natively |
| `rust-toolchain.toml` | rustup | Channel + components |
| `rust-toolchain` | rustup (legacy) | Single channel string |
| `.go-version` | goenv | Single version string |

**Task runner files to detect:**

| File | Runner | Migration complexity |
|------|--------|---------------------|
| `Makefile` | make | Medium — targets map to tasks, but shell idioms vary |
| `justfile` | just | Low — recipes map cleanly to mise tasks |
| `package.json` (scripts) | npm/pnpm/yarn | Low — script commands map directly |
| `Taskfile.yml` | Task (go-task) | Low — YAML tasks map to TOML tasks |
| `Rakefile` | rake | High — Ruby DSL, often complex |
| `Gruntfile.js` / `Gulpfile.js` | grunt/gulp | Medium — pipeline patterns differ |
| `Procfile` | foreman/heroku | Low — process declarations map to tasks |

**Project structure to detect:**

| Signal | Indicates |
|--------|-----------|
| `Cargo.toml` with `[workspace]` | Rust workspace (monorepo candidate) |
| `pnpm-workspace.yaml` or `lerna.json` | JS monorepo |
| Multiple `package.json` files in subdirs | JS monorepo |
| `go.work` | Go workspace |
| Multiple independently-buildable subdirectories | General monorepo candidate |

### Phase 2: Present Findings

Show the user what was detected, organized by category:

```
## Detected Configuration

### Toolchain
- .nvmrc: Node 20
- rust-toolchain.toml: stable, components: clippy, rustfmt

### Task Runners
- justfile: 12 recipes (build, test, lint, deploy, ...)
- package.json scripts: 4 scripts (dev, build, test, lint)

### Project Structure
- Cargo workspace with 3 members (crates/core, crates/api, services/worker)
- Node package in packages/frontend
```

### Phase 3: Present Options

Always present these options. Let the user choose — don't assume.

**Option A — Toolchain only**
- Generate `mise.toml` with `[tools]` from detected toolchain files
- Keep existing task runner as-is
- Best when: the existing task runner is mature and well-maintained, or the team is attached to it

**Option B — Toolchain + tasks**
- Generate `mise.toml` with `[tools]` and `[tasks]`
- Migrate detected task runner entries to mise tasks
- Keep original task runner file until migration is verified
- Best when: consolidating tools, or the existing task runner is simple

**Option C — Toolchain + monorepo tasks** (if monorepo detected)
- Generate root `mise.toml` with shared tools and orchestration tasks
- Generate per-package `mise.toml` files with package-specific tasks
- Enable `experimental_monorepo_root`
- Best when: the project has distinct buildable components that should own their tasks
- Load `references/monorepo-tasks.md` for detailed patterns

**Option D — Local-only setup** (mise.local.toml)
- Generate `mise.local.toml` instead of `mise.toml`
- For contributing to repos you don't control
- Best when: you want mise benefits without modifying the project

### Phase 4: Generate Configuration

Based on the user's choice, generate the configuration files.

**For every option:**
1. Generate the appropriate `mise.toml` (or `mise.local.toml`)
2. Check `.gitignore` for `mise.local.toml` — suggest adding if missing
3. Run `mise install` to provision tools
4. Run `mise ls` to verify tools are active
5. Suggest committing `mise.lock` for reproducibility

**For task migration (Options B and C):**
1. Map existing tasks to mise task definitions
2. Use task-specific `tools` for tools only needed by certain tasks
3. Preserve task names where possible for team familiarity
4. Keep the original task runner file — don't delete it until the user verifies
5. Suggest running migrated tasks to verify behavior matches

**For monorepo setup (Option C):**
1. Identify config roots from workspace/project structure
2. Generate root `mise.toml` with `experimental_monorepo_root = true`
3. Generate per-package `mise.toml` with local tasks
4. Show how to run with `MISE_EXPERIMENTAL=1`

### Phase 5: Verification

After generating configuration:
1. Run `mise install` — confirm tools install successfully
2. Run `mise ls` — confirm versions match expectations
3. If tasks were migrated, run each task and compare output to the original
4. Suggest the user run their normal workflow for a day before removing the original task runner

## Task Migration Patterns

### justfile → mise tasks

```just
# justfile
build:
    cargo build --release

test: build
    cargo nextest run

deploy env="staging": build
    flyctl deploy --env {{env}}
```

Maps to:
```toml
[tasks.build]
run = "cargo build --release"

[tasks.test]
run = "cargo nextest run"
depends = ["build"]

[tasks.deploy]
run = "flyctl deploy --env {{arg(name='env')}}"
depends = ["build"]
tools = { "aqua:flyctl" = "latest" }
usage = 'arg "<env>" default="staging"'
```

### package.json scripts → mise tasks

```json
{ "scripts": {
    "dev": "next dev",
    "build": "next build",
    "lint": "eslint ."
}}
```

Maps to:
```toml
[tasks.dev]
run = "next dev"

[tasks.build]
run = "next build"

[tasks.lint]
run = "eslint ."
```

### Makefile → mise tasks

```makefile
.PHONY: build test
build:
	cargo build --release

test: build
	cargo test
```

Maps to:
```toml
[tasks.build]
run = "cargo build --release"

[tasks.test]
run = "cargo test"
depends = ["build"]
```

Note: Makefile variable expansion, conditionals, and implicit rules don't have direct mise equivalents. Complex Makefiles may be better left as-is (Option A).

## Toolchain File Conversion

### .nvmrc → mise.toml

```
# .nvmrc
20
```
→
```toml
[tools]
node = "20"
```

### rust-toolchain.toml → mise.toml

```toml
# rust-toolchain.toml
[toolchain]
channel = "stable"
components = ["clippy", "rustfmt"]
```
→
```toml
[tools]
rust = { version = "latest", components = "clippy,rustfmt" }
```

Note: mise reads `rust-toolchain.toml` natively. Only convert if you want a single source of truth in `mise.toml`. Keeping both is also fine — mise respects `rust-toolchain.toml` automatically.

### .tool-versions → mise.toml

```
# .tool-versions
nodejs 20.11.0
python 3.12.1
```
→
```toml
[tools]
node = "20.11.0"
python = "3.12.1"
```

mise reads `.tool-versions` natively. Convert only if you want `mise.toml` features (env vars, tasks, tool options).

## STOP — Before You Start

| You're about to... | Why it's wrong | What to do instead |
|--------------------|----------------|--------------------|
| Delete the existing task runner immediately | Team members who don't use mise yet will break | Keep it alongside mise tasks until migration is verified |
| Convert `rust-toolchain.toml` without asking | mise reads it natively — converting may not add value | Present as an option, explain trade-offs |
| Assume the user wants full migration | They may only want toolchain management | Always present Option A first |
| Skip verification | "The config looks right" | Run `mise install`, `mise ls`, and test each migrated task |
| Generate `mise.toml` for a repo the user doesn't control | That's what `mise.local.toml` is for | Ask about repo ownership first |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Migrating tasks without testing them | Run each migrated task before removing the original |
| Forgetting `.gitignore` for `mise.local.toml` | Check and suggest adding it |
| Not committing `mise.lock` | Always suggest committing for reproducibility |
| Converting files mise already reads natively | Explain that `.nvmrc`, `.tool-versions`, `rust-toolchain.toml` work without conversion |
