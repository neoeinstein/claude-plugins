# Claude Plugins Marketplace and Rust Plugin Design

## Summary

This design establishes a Claude Code plugin marketplace repository that will distribute multiple domain-specific plugins via a single GitHub repository. The primary deliverable is a production-ready `rust-best-practices` plugin that consolidates and improves existing Rust development guidance — migrating a skill and formatting hook from local configuration into a distributable plugin with expanded best practices content, anti-rationalization guidance, and intelligent rustfmt integration. Additionally, the repository scaffolds three more plugins (askama, htmx-alpine, mise) with enough structure to support immediate installation and future design sessions.

The implementation uses a monorepo structure where each plugin lives in `plugins/` with its own manifest, and a root marketplace manifest catalogs all available plugins. Users add the marketplace once with `/plugin marketplace add neoeinstein/claude-plugins`, then selectively install individual plugins. The Rust plugin enhances the existing skill with structural patterns from the ed3d ecosystem (expanded core principles, anti-rationalization tables, "STOP" warnings on high-risk patterns) while preserving the task-to-reference lookup tables that make it effective. The auto-formatting hook gains nightly/stable rustfmt fallback logic based on `rustfmt.toml` presence, ensuring compatibility across projects with varying formatting requirements.

## Definition of Done

1. **A Claude plugins marketplace repository** initialized with git, containing a `marketplace.json` that can be added via `/plugin marketplace add neoeinstein/claude-plugins`.

2. **A `rust-best-practices` plugin** within it containing:
   - An improved best-practices skill (structurally and content-reviewed against ed3d patterns, with identified improvements applied)
   - An auto-formatting hook that uses nightly `rustfmt` when a `rustfmt.toml` exists in the project, and stable `rustfmt` otherwise
   - The existing 14 reference docs, improved where the review identifies gaps

3. **Scaffolding for 3 additional plugins** (askama, htmx-alpine, mise) with:
   - Directory structure and empty/minimal plugin manifests
   - Enough structure that follow-up design sessions can begin immediately
   - Brief design notes capturing what was discussed in this session about each plugin's intended scope

4. **A documented repo structure** that makes it clear how plugins are organized and how to add new ones.

## Glossary

- **Marketplace**: A Claude Code plugin distribution mechanism where a single repository catalogs multiple plugins via a `marketplace.json` file, allowing users to discover and install plugins from a centralized source.
- **Plugin**: A distributable unit of Claude Code functionality containing skills, hooks, or both, defined by a `plugin.json` manifest.
- **Skill**: A structured knowledge document (SKILL.md) that Claude Code loads to provide domain-specific guidance during development tasks. Skills can include reference documents for deep-dive topics.
- **Hook**: A script that executes automatically in response to Claude Code events (e.g., PostToolUse fires after Write/Edit operations), enabling workflow automation like code formatting.
- **Anti-rationalization table**: A structural pattern from the ed3d plugin ecosystem that preemptively addresses common justifications for breaking best practices, helping Claude Code recognize when it's about to make a poor decision.
- **"STOP and reconsider" section**: A warning pattern in reference documents that flags high-risk operations (like `.unwrap()` or `unsafe` without comments) requiring explicit justification.
- **FCIS (Functional Core, Imperative Shell)**: An architectural pattern separating pure business logic from I/O and side effects, adapted here for Rust with module organization guidance.
- **rustfmt**: Rust's official code formatter. The nightly toolchain version supports additional formatting options configured via `rustfmt.toml`.
- **Nightly toolchain**: A Rust compiler/toolchain distribution updated daily with experimental features. Some projects require nightly rustfmt for advanced formatting configurations.
- **PostToolUse**: A hook trigger type that fires after Claude Code completes a tool operation (Write, Edit, etc.), used here to auto-format Rust files after modification.
- **pluginRoot**: A marketplace.json configuration property that sets the base directory for plugin source paths, allowing relative path resolution.
- **Newtypes**: A Rust pattern using zero-cost wrapper types to encode domain constraints at the type level, preventing invalid state.
- **Proptest**: A Rust property-based testing framework for generating test cases from properties rather than writing explicit examples.
- **TryFrom**: A Rust trait for fallible conversions, commonly used to implement validated construction of types that enforce invariants.
- **MutexGuard**: A Rust RAII guard type returned when locking a Mutex. Holding it across `.await` points risks deadlocks in async code.

## Architecture

This repository is a Claude Code plugin marketplace — a monorepo containing multiple independent plugins distributed via a single `.claude-plugin/marketplace.json`. Users add the marketplace with `/plugin marketplace add neoeinstein/claude-plugins` and then selectively install individual plugins.

### Repository layout

```
claude-plugins/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   ├── rust-best-practices/        # Primary plugin (this design)
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   ├── skills/
│   │   │   └── rust-best-practices/
│   │   │       ├── SKILL.md
│   │   │       └── references/     # 14+ reference docs
│   │   └── hooks/
│   │       ├── hooks.json
│   │       └── format-rust.sh
│   ├── askama/                     # Scaffold
│   ├── htmx-alpine/               # Scaffold
│   └── mise/                      # Scaffold
├── .gitignore
└── README.md
```

The `marketplace.json` uses `pluginRoot: "./plugins"` so plugin source paths are relative to the `plugins/` directory.

### Rust plugin components

The `rust-best-practices` plugin has two components:

1. **Skill**: A best-practices reference skill with a main SKILL.md index that dispatches to topic-specific reference documents. The skill is structurally improved over the existing version with expanded core principles, anti-rationalization tables, and "STOP" patterns on high-impact reference docs.

2. **Hook**: A PostToolUse hook on `Write|Edit` that auto-formats `.rs` files with `rustfmt`. Uses nightly toolchain when a `rustfmt.toml` exists (indicating the project uses nightly-only formatting options), falls back to stable otherwise.

### Placeholder plugins

Three additional plugin directories (askama, htmx-alpine, mise) contain valid manifests and minimal skill stubs so they can be installed immediately but are marked as `0.1.0` to signal incomplete status. Each includes a `docs/design-notes.md` capturing scope decisions from this session.

## Existing Patterns

This is a greenfield repository — no existing codebase patterns to follow.

The design draws structural inspiration from:

- **ed3d plugin ecosystem**: Flat plugin directories within a marketplace, each with `.claude-plugin/plugin.json` manifests. The `ed3d-house-style` plugin's `coding-effectively` meta-skill pattern informed the approach to expanding the SKILL.md core principles section as an "always loaded" cross-cutting concerns layer.

- **Existing `rust-best-practices` skill** at `~/.claude/skills/rust-best-practices/`: The current task-to-reference and error-to-reference lookup tables are retained as-is — these are a structural strength not found in ed3d's approach.

- **Existing `format-rust.sh` hook** at `~/.claude/hooks/format-rust.sh` in the constant-gathering project: The current hook structure (PostToolUse on Write|Edit, shell script, 30s timeout) is preserved. The nightly/stable fallback logic and `rustfmt.toml` detection are new.

- **Existing HTMX+Alpine patterns** at `constant-gathering/CLAUDE.md` lines 325-415: The server-driven interactions pattern, client-side state boundaries, and "when NOT to use JavaScript" guidance serve as seed content for the htmx-alpine plugin stub.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Repository and marketplace infrastructure

**Goal:** Initialize the repository with git, marketplace manifest, and the directory structure for all four plugins.

**Components:**
- `.claude-plugin/marketplace.json` — marketplace catalog listing all four plugins
- `plugins/rust-best-practices/.claude-plugin/plugin.json` — Rust plugin manifest
- `plugins/askama/.claude-plugin/plugin.json` — Askama plugin manifest
- `plugins/htmx-alpine/.claude-plugin/plugin.json` — HTMX+Alpine plugin manifest
- `plugins/mise/.claude-plugin/plugin.json` — mise plugin manifest
- `.gitignore` — standard ignores
- `README.md` — repository overview explaining the marketplace structure and how to install

**Dependencies:** None (first phase)

**Done when:** Repository has valid git history, `marketplace.json` is valid, all four plugin manifests exist, README explains the structure.
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Migrate and improve Rust skill — SKILL.md and core structure

**Goal:** Migrate the existing `rust-best-practices` SKILL.md and improve it with expanded core principles and anti-rationalization content.

**Components:**
- `plugins/rust-best-practices/skills/rust-best-practices/SKILL.md` — migrated from `~/.claude/skills/rust-best-practices/SKILL.md` with these improvements:
  - Core Principles expanded from 4 to ~7 bullets, adding: FCIS for Rust (separate pure logic from I/O), validate at construction (`TryFrom`/newtypes), prefer minimal visibility
  - Anti-rationalization table (6-8 entries covering `.unwrap()`, newtypes, validation, async safety, unsafe, exhaustive enums)
  - Updated task-to-reference table with new references (fcis, expanded testing)

**Dependencies:** Phase 1 (directory structure)

**Done when:** SKILL.md is in place with expanded principles and anti-rationalization content. Lookup tables reference all reference docs including new ones.
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: Migrate and improve reference docs

**Goal:** Migrate all 14 existing reference docs and add targeted improvements.

**Components:**
- `plugins/rust-best-practices/skills/rust-best-practices/references/` — all 14 existing reference docs migrated from `~/.claude/skills/rust-best-practices/references/`
- **Modified docs:**
  - `error-handling.md` — add "STOP and reconsider" section for `.unwrap()` in non-test contexts and `panic!()` in library code
  - `async.md` — add "STOP and reconsider" section for holding `MutexGuard` across `.await`, spawning without `JoinHandle` tracking, unbounded channels
  - `unsafe.md` — add "STOP and reconsider" section for `unsafe` without `SAFETY` comments, `mem::transmute`
  - `testing.md` — expand significantly: testing philosophy (behavior over implementation), integration vs unit test strategy in Rust, mocking strategy, property-based testing depth with proptest property catalog
  - `type-safety.md` or `error-handling.md` — add infallible parsing pattern: `let Ok(x) = expr;` for `Result<T, Infallible>` instead of `.parse().unwrap()`, since `Infallible` is uninhabited and the `Err` case compiles as an irrefutable pattern
- **New doc:**
  - `references/fcis.md` — FCIS for Rust: module organization (pure `domain` modules vs I/O `service` modules), leveraging type signatures for boundary visibility, gather-process-persist pattern with Rust examples

**Dependencies:** Phase 2 (SKILL.md references these docs)

**Done when:** All 15 reference docs (14 migrated + 1 new) are in place. Modified docs include their STOP sections. Testing doc has expanded content.
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: Auto-formatting hook

**Goal:** Create the improved rustfmt hook with nightly/stable fallback logic.

**Components:**
- `plugins/rust-best-practices/hooks/format-rust.sh` — shell script that:
  1. Extracts file path from tool input, bails if not `.rs`
  2. Walks up directories from the file to find `rustfmt.toml` or `.rustfmt.toml`
  3. If config found: tries `rustfmt +nightly`, falls back to `rustfmt` (stable)
  4. If no config: uses `rustfmt` (stable) directly
  5. Exits 0 on any failure (don't block edits)
- `plugins/rust-best-practices/hooks/hooks.json` — PostToolUse on `Write|Edit`, references `${CLAUDE_PLUGIN_ROOT}/hooks/format-rust.sh`

**Dependencies:** Phase 1 (directory structure)

**Done when:** Hook script handles all four scenarios correctly (nightly+config, stable-fallback+config, stable-only+no-config, no-rustfmt-available). `hooks.json` is valid.
<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: Placeholder plugins — askama, htmx-alpine, mise

**Goal:** Create functional but minimal plugin stubs for the three remaining plugins with design notes for follow-up sessions.

**Components:**
- **Askama plugin:**
  - `plugins/askama/skills/askama-rust-templates/SKILL.md` — migrated from `~/.claude/skills/askama-rust-templates/SKILL.md`
  - `plugins/askama/skills/askama-debugging/SKILL.md` — migrated from `~/.claude/skills/askama-debugging/SKILL.md`
  - `plugins/askama/docs/design-notes.md` — notes on future improvements (structural review, expanded examples)

- **HTMX+Alpine plugin:**
  - `plugins/htmx-alpine/skills/htmx-alpine/SKILL.md` — stub seeded from `constant-gathering` CLAUDE.md HTMX+Alpine patterns, framed as general/cross-language guidance
  - `plugins/htmx-alpine/docs/design-notes.md` — notes on future design scope (htmx.org research, hx-boost, SSE/WebSocket extensions, error handling, deeper Alpine integration)

- **mise plugin:**
  - `plugins/mise/skills/mise/SKILL.md` — stub covering the two modes: `mise.toml` for repos you control, `mise.local.toml` for repos you don't
  - `plugins/mise/docs/design-notes.md` — notes on future design scope (hook exploration for SessionStart context injection, toolchain detection)

**Dependencies:** Phase 1 (directory structure)

**Done when:** All three plugins can be installed via the marketplace. Skills have at minimum a description and "when to use" section. Design notes capture scope decisions.
<!-- END_PHASE_5 -->

## Additional Considerations

**Plugin naming and namespacing:** When installed, skills from these plugins appear as `rust-best-practices:rust-best-practices`, `askama:askama-rust-templates`, etc. The plugin name becomes the namespace prefix. This is why the plugin names are domain-focused rather than author-prefixed — users see clean names in their skill lists.

**Versioning strategy:** The Rust plugin starts at `1.0.0` since its content is mature. Placeholder plugins start at `0.1.0` to signal they're stubs awaiting full design. Versions are tracked both in each plugin's `plugin.json` and in the root `marketplace.json`.

**Migration path for existing users:** After implementation, the user should update their `~/.claude/settings.json` to enable the marketplace-installed plugins and disable the local `~/.claude/skills/` versions to avoid duplicate skill loading.
