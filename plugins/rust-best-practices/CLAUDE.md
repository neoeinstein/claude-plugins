# rust-best-practices Plugin

Last verified: 2026-02-04

## Purpose

Primary plugin providing idiomatic Rust development guidance. Bundles a skill with lazy-loaded reference docs and an auto-formatting hook.

## Contracts

- **Exposes**: `rust-best-practices:rust-best-practices` skill, PostToolUse formatting hook
- **Guarantees**: Hook is fail-open (never blocks edits). Reference docs are self-contained and independently loadable. SKILL.md provides lookup tables mapping tasks and error messages to specific reference docs.
- **Expects**: `rustfmt` available on PATH for hook. Nightly toolchain optional (used when `rustfmt.toml` exists).

## Key Decisions

- **Lazy-loading over always-loaded**: Reference docs loaded on-demand via SKILL.md lookup tables, not bundled into the skill. Keeps token cost low.
- **Nightly/stable fallback in hook**: When `rustfmt.toml` or `.rustfmt.toml` exists (walks up from file), tries nightly first (for nightly-only options), falls back to stable. No config means stable only.
- **Anti-rationalization tables**: STOP sections in SKILL.md and key reference docs (error-handling, async, unsafe) to prevent common rationalizations for bad patterns.
- **FCIS over file classification comments**: Module organization approach adapted for Rust. Pure domain logic separated from I/O at the module level, not via per-file annotations.

## Dependencies

- **Uses**: `rustfmt` (external), optionally `rustfmt +nightly`
- **Used by**: Any Rust project that installs this plugin
- **Boundary**: This plugin is language-specific to Rust

## Key Files

- `skills/rust-best-practices/SKILL.md` -- Main skill with lookup tables and core principles
- `skills/rust-best-practices/references/` -- 15 reference docs (async, error-handling, type-safety, unsafe, testing, etc.)
- `hooks/format-rust.sh` -- PostToolUse hook for rustfmt
- `hooks/hooks.json` -- Hook configuration (triggers on Write|Edit)

## Invariants

- Hook must exit 0 on any failure (fail-open design, no `set -e`)
- Hook only processes `.rs` files
- Every reference doc must be loadable independently (no cross-references required)
- SKILL.md lookup tables must cover all reference docs
