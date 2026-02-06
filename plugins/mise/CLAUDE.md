# mise Plugin

Last verified: 2026-02-06

## Purpose

Guidance for using mise as a toolchain manager. Covers `mise.toml` (repos you control) and `mise.local.toml` (repos you contribute to). Includes SessionStart hook for toolchain detection.

## Contracts

- **Exposes**: `mise:mise` skill with 4 reference docs
- **Guarantees**: Reference docs are lazy-loaded via SKILL.md lookup tables. SessionStart hook is fail-open, primes agent without prescribing actions, never modifies project directory.
- **Expects**: User working with or setting up mise for toolchain management

## Key Decisions

- **mise.toml vs mise.local.toml**: Core distinction emphasized throughout. Team config is committed; personal config is gitignored.
- **SessionStart hook primes agent context**: Outputs runtime-vs-library-deps distinction and points to mise skill. Three modes: team config (mise.toml), local config (mise.local.toml), no config. Never writes to project directory.
- **Troubleshooting has STOP section**: Addresses the "remove mise from CI when rate limited" anti-pattern.

## Key Files

- `skills/mise/SKILL.md` — Main skill with lookup tables and anti-rationalization table
- `skills/mise/references/configuration.md` — mise.toml structure, precedence, environment
- `skills/mise/references/tasks.md` — Task runner, dependencies, watch mode
- `skills/mise/references/troubleshooting.md` — Command-not-found, rate limiting, STOP section
- `skills/mise/references/ci-cd.md` — GitHub Actions, lockfiles, caching
- `hooks/hooks.json` — SessionStart hook configuration
- `hooks/detect-toolchain.sh` — Agent priming: runtime vs library deps, skill reference

## Invariants

- Every reference doc must be loadable independently
- SKILL.md lookup tables must cover all reference docs
- Hook must be fail-open (always exit 0)
- Hook must never modify the project directory
- Hook must always output agent context (distinguishes team/local/no config)
