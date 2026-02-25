---
name: mise
description: Use when setting up development toolchains with mise, managing tool versions, configuring project environments, or defining build/test/deploy tasks - covers both mise.toml for repos you control and mise.local.toml for repos you contribute to
---

# mise Toolchain Management

## Overview

mise manages development tool versions, environment configuration, and project tasks. Use it to ensure consistent toolchains across team members and CI, and to define build/test/deploy workflows alongside your toolchain.

**Core principle:** Two modes — `mise.toml` for repos you control (committed), `mise.local.toml` for repos you contribute to (gitignored).

## Quick Reference - What to Load

| If you're... | Load |
|--------------|------|
| Adopting mise in an existing project | Use `mise:onboard-project` skill instead |
| Setting up mise.toml, understanding precedence | `references/configuration.md` |
| Defining tasks, running builds, watch mode | `references/tasks.md` |
| Declaring task-specific tool requirements | `references/tasks.md` |
| Organizing tasks across packages in a monorepo | `references/monorepo-tasks.md` |
| Decomposing a flat taskfile into per-component definitions | `references/monorepo-tasks.md` |
| Seeing "command not found", activation issues | `references/troubleshooting.md` |
| Setting up GitHub Actions, lockfiles | `references/ci-cd.md` |

## When to Use Each Config

| Scenario | Config File | Committed? |
|----------|------------|------------|
| Your project, team-wide tools | `mise.toml` | Yes |
| Contributing to someone else's repo | `mise.local.toml` | No (gitignored) |
| User-wide defaults | `~/.config/mise/config.toml` | N/A |

## Core Principles

**mise.toml for Team Configuration:** When you control the repo, use `mise.toml` to define the project's required toolchain. Commit it. Everyone gets the same versions.

**mise.local.toml for Personal Tools:** When contributing to repos you don't control, use `mise.local.toml` for your personal tool preferences. It's gitignored by convention.

**Always Run mise install:** After cloning a project with `mise.toml`, run `mise install` to provision the tools. This is not automatic.

**Prefer Activation over Shims:** Use `mise activate` in your shell rc file for full feature support. Shims work but have limitations (no environment variable updates except on tool invocation).

**Commit mise.lock for Reproducibility:** The lockfile ensures everyone gets identical tool versions and avoids rate limiting issues.

## STOP — Anti-Rationalization Table

Before writing code that matches these patterns, STOP and reconsider.

| You're about to... | Common rationalization | What to do instead |
|--------------------|------------------------|--------------------|
| Add `mise activate` to CI script | "It works locally" | CI is non-interactive. Use `mise x -- command` or shims. Load `references/ci-cd.md`. |
| Skip `mise.lock` in the repo | "We're using 'latest'" | 'Latest' changes. Commit the lockfile for reproducibility. Load `references/ci-cd.md`. |
| Remove mise from CI after rate limit | "It's blocking deploys" | Set `GITHUB_TOKEN` for higher limits. Removing mise just moves the problem. Load `references/troubleshooting.md`. |
| Commit `mise.local.toml` | "Team should have these tools too" | That's what `mise.toml` is for. Local files are personal. |
| Use `.bash_profile` for activation | "It's where I put PATH" | Activation only works in `.bashrc`/`.zshrc`. Load `references/troubleshooting.md`. |
| Pin exact patch versions everywhere | "Maximum reproducibility" | Use `mise.lock` instead. Pins in config make updates tedious. |
| Add a tool to project `[tools]` that only one task needs | "It's easier" / "Everyone might use it" | Put it in `tasks.<name>.tools`. Contributors who never run that task skip the install. Load `references/tasks.md`. |
| Put all tasks in the root mise.toml for a multi-package project | "It's simpler" / "One file to check" | Each package should own its tasks in its own `mise.toml`. Root orchestrates. Load `references/monorepo-tasks.md`. |

## Common Tool Configurations

### Rust

```toml
[tools]
rust = { version = "latest", components = "clippy,rustfmt" }
"cargo:cargo-nextest" = "latest"
"cargo:cargo-watch" = "latest"
```

### Node.js

```toml
[tools]
node = "lts"
"npm:pnpm" = "latest"
```

### Python

```toml
[tools]
python = "3.12"
"pipx:poetry" = "latest"
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Committing `mise.local.toml` | Add to `.gitignore` |
| Using `mise.local.toml` in your own repo | Use `mise.toml` — let contributors benefit |
| Forgetting `mise install` after cloning | Add to project setup docs |
| Missing `GITHUB_TOKEN` in CI | Set token for API rate limits |
| Activation in `.bash_profile` | Use `.bashrc` or `.zshrc` instead |

## Authoritative Resources

- [mise Documentation](https://mise.jdx.dev/)
- [Configuration Reference](https://mise.jdx.dev/configuration.html)
- [Task Runner](https://mise.jdx.dev/tasks/)
- [Task Configuration](https://mise.jdx.dev/tasks/task-configuration.html)
- [Monorepo Tasks](https://mise.jdx.dev/tasks/monorepo.html) (experimental)
- [CI/CD Integration](https://mise.jdx.dev/continuous-integration.html)

