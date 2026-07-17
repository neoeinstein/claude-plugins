# rust-best-practices Plugin

Last verified: 2026-07-17

## Purpose

Primary plugin providing idiomatic Rust development guidance. Bundles two skills with lazy-loaded reference docs and an auto-formatting hook.

## Contracts

- **Exposes**: `rust-best-practices:rust-best-practices` and `rust-best-practices:facet` skills, PostToolUse formatting hook
- **Guarantees**: Hook is fail-open (never blocks edits). Reference docs are self-contained and independently loadable. SKILL.md provides lookup tables mapping tasks and error messages to specific reference docs.
- **Expects**: `rustfmt` reachable by the hook -- via a mise `rust` pin, a `rust-toolchain.toml`, or on PATH. `jq` required (parses hook stdin). Nightly toolchain optional (PATH fallback, used when `rustfmt.toml` exists).

## Key Decisions

- **Lazy-loading over always-loaded**: Reference docs loaded on-demand via SKILL.md lookup tables, not bundled into the skill. Keeps token cost low.
- **Toolchain selection precedence (hook)**: The hook picks rustfmt by a 4-tier precedence so it matches how the repo's own gates resolve the toolchain, not whatever rustfmt is first on PATH: (1) **repo-local mise pin** -- repo pins `rust` in its own mise config (detected via `mise ls --current --installed rust --json` whose `source.path` sits at/above the file, *not* `mise which` -- which falls back to PATH) -> `mise exec -- rustfmt`; (2) **`rust-toolchain.toml`/`rust-toolchain`** present -> defer to it (plain rustfmt with `RUSTUP_TOOLCHAIN` unset so rustup reads the file), rather than let a user-global mise pin override the repo's canonical pin; (3) **user-global mise pin** -> `mise exec -- rustfmt`; (4) **plain PATH rustfmt** -> nightly when a `rustfmt.toml`/`.rustfmt.toml` exists (nightly-only options), stable otherwise.
- **Why route through mise**: `mise exec` sets `RUSTUP_TOOLCHAIN` to the pin and prepends its rust bin, so it wins over a stale `RUSTUP_TOOLCHAIN` in the process environment, a stale PATH entry, `rust-toolchain.toml`, and the rustup default -- all of which can otherwise silently format with the wrong (e.g. previously-pinned) toolchain. The selected toolchain is authoritative: on failure the hook fails open rather than reformatting with a mismatched rustfmt.
- **Edition resolution (hook)**: Every tier runs a *bare* `rustfmt <file>`, which does not read `Cargo.toml` and defaults to **edition 2015** -- so it silently disagreed with `cargo fmt` (which passes the crate's real edition) on import sort order and layout, re-mangling on every save. The hook now resolves the edition the way cargo does (`crate_edition`: walk up for the first literal `edition = "NNNN"`; members inheriting `edition.workspace = true` resolve at the workspace root) and passes `--edition` to every invocation. This also fixes files using edition-2024-only syntax (e.g. let-chains) that edition-2015 rustfmt couldn't parse and silently skipped.
- **Anti-rationalization tables**: STOP sections in SKILL.md and key reference docs (error-handling, async, unsafe) to prevent common rationalizations for bad patterns.
- **FCIS over file classification comments**: Module organization approach adapted for Rust. Pure domain logic separated from I/O at the module level, not via per-file annotations.

## Dependencies

- **Uses**: `rustfmt` (external), optionally via `mise exec` (when mise pins `rust`) or `rustfmt +nightly`; `jq` for parsing hook input
- **Used by**: Any Rust project that installs this plugin
- **Boundary**: This plugin is language-specific to Rust

## Key Files

- `skills/rust-best-practices/SKILL.md` -- Main skill with lookup tables and core principles
- `skills/rust-best-practices/references/` -- 17 reference docs (async, error-handling, type-safety, unsafe, testing, lint-setup, responding-to-lints, etc.)
- `skills/facet/SKILL.md` -- facet-ecosystem skill (loads on its own triggers) with 7 reference docs
- `hooks/format-rust.sh` -- PostToolUse hook for rustfmt
- `hooks/hooks.json` -- Hook configuration (triggers on Write|Edit)

## Invariants

- Hook must exit 0 on any failure (fail-open design, no `set -e`)
- Hook only processes `.rs` files
- Every reference doc must be loadable independently (no cross-references required)
- SKILL.md lookup tables must cover all reference docs
