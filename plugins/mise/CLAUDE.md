# mise Plugin

Last verified: 2026-02-05

## Purpose

Guidance for using mise as a toolchain manager. Covers `mise.toml` (repos you control) and `mise.local.toml` (repos you contribute to). Includes SessionStart hook for toolchain detection.

## Contracts

- **Exposes**: `mise:mise` skill with 4 reference docs
- **Guarantees**: Reference docs are lazy-loaded via SKILL.md lookup tables. SessionStart hook is fail-open and non-intrusive (single-line suggestion, fires once per project).
- **Expects**: User working with or setting up mise for toolchain management

## Key Decisions

- **mise.toml vs mise.local.toml**: Core distinction emphasized throughout. Team config is committed; personal config is gitignored.
- **SessionStart hook is minimal**: Creates marker file to fire once per project. Silent if mise.toml exists. No plugin suggestions (too pushy).
- **Troubleshooting has STOP section**: Addresses the "remove mise from CI when rate limited" anti-pattern.

## Key Files

- `skills/mise/SKILL.md` — Main skill with lookup tables and anti-rationalization table
- `skills/mise/references/configuration.md` — mise.toml structure, precedence, environment
- `skills/mise/references/tasks.md` — Task runner, dependencies, watch mode
- `skills/mise/references/troubleshooting.md` — Command-not-found, rate limiting, STOP section
- `skills/mise/references/ci-cd.md` — GitHub Actions, lockfiles, caching
- `hooks/hooks.json` — SessionStart hook configuration
- `hooks/detect-toolchain.sh` — Minimal toolchain detection script

## Invariants

- Every reference doc must be loadable independently
- SKILL.md lookup tables must cover all reference docs
- Hook must be fail-open (always exit 0)
- Hook must fire only once per project (marker file)
- Hook must be silent when mise.toml exists
