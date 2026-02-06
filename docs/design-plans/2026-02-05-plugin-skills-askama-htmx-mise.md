# Plugin Skills Design: Askama, HTMX-Alpine, and Mise

## Summary

This design elevates three stub plugins (askama, htmx-alpine, mise) to production readiness by applying the proven rust-best-practices template structure. Each plugin provides a master SKILL.md that serves as an index/dispatcher with task-to-reference lookup tables, enabling lazy-loaded reference docs for deep-dive topics. The approach emphasizes TDD validation through pressure testing — running specific scenarios that combine time pressure, sunk costs, authority bias, and muscle memory to ensure skills actively resist rationalization rather than merely documenting best practices.

The plugins remain independently installable but include soft cross-references where domains naturally overlap (askama's HTMX fragment rendering points to htmx-alpine; htmx-alpine's Rust integration points back to askama). The mise plugin adds a minimal SessionStart hook for toolchain detection that suggests missing mise.toml configuration without being intrusive. All three plugins follow the token-efficient pattern of anti-rationalization tables in master skills and STOP sections only in high-impact reference docs (1-2 per plugin).

## Definition of Done

1. **Three comprehensive plugin designs** (askama, htmx-alpine, mise) — each with:
   - Restructured SKILL.md files following ed3d-house-style patterns (anti-rationalization tables, STOP sections, quick self-checks)
   - Reference docs for deep-dive topics (lazy-loaded, not force-included)
   - TDD-validated content (baseline test → write skill → pressure test → iterate)

2. **Cross-plugin coordination hooks** — mise can suggest toolchains relevant to other plugins; plugins can reference each other where appropriate

3. **htmx-alpine framework variants** — Language-agnostic core skill + optional framework-specific reference docs (axum+askama, Django, Go templates)

4. **mise SessionStart hook design** — Toolchain detection and context injection for project setup

**Success Criteria:**
- Each skill passes pressure testing (resists rationalization under combined pressures)
- Skills follow consistent structure (Overview, When to Use, Core Pattern, Anti-Rationalization, Red Flags, Quick Reference)
- Token-efficient design (lazy-loading references, no always-loaded bloat)

**Out of Scope:**
- Actual implementation of skills (that's the implementation plan)
- Changes to rust-best-practices plugin (already at v1.0.0)

## Glossary

- **Askama**: Rust templating library using compile-time template validation and Jinja2-like syntax
- **HTMX**: JavaScript library for building hypermedia-driven UIs using HTML attributes instead of client-side routing
- **Alpine.js**: Minimal JavaScript framework for declarative client-state management via x-data and x-model attributes
- **Mise**: Modern polyglot tool version manager (successor to asdf) handling language runtimes and project-local toolchains
- **Anti-rationalization table**: Structured reference mapping common bad patterns to the rationalizations developers use to justify them and correct alternatives
- **STOP section**: Compliance enforcement pattern using strong language to interrupt rationalization at decision points
- **Pressure testing**: TDD validation approach combining time constraints, sunk costs, authority bias, and familiarity to test if skills resist rationalization
- **Lazy-loading**: Pattern where reference docs are not force-included but retrieved on-demand via lookup tables
- **SessionStart hook**: Plugin hook that fires once per project session for environment detection and setup suggestions
- **Fail-open design**: Hook architecture where failures never block user operations (opposite of fail-closed)
- **Soft pointer**: Cross-plugin reference that suggests related plugins without creating hard dependencies
- **hx-swap/hx-target**: HTMX attributes controlling where and how server responses update the DOM
- **x-data/x-model**: Alpine.js attributes for declaring reactive component state and two-way data binding
- **mise.toml**: Configuration file declaring project toolchains and task definitions for mise
- **Axum**: Rust web framework built on Tokio for async HTTP handlers

## Architecture

This design transforms three stub plugins into comprehensive skill packages following the proven rust-best-practices template. Each plugin uses a master SKILL.md as an index/dispatcher with lazy-loaded reference docs for deep-dive topics.

### Unified Skill Template

All three plugins follow this structure:

**SKILL.md (Master Index):**
- Overview — Core principle in 1-2 sentences
- Quick Reference — What to Load (task→doc lookup table)
- Core Principles — 3-6 domain-specific principles
- STOP — Anti-Rationalization (pattern→fix table, 5-8 entries)
- Authoritative Resources — External references

**Reference Docs (Lazy-Loaded):**
- When to Use This Reference — Scenarios for loading
- Quick Reference — Scannable table
- The Rule — Core principle with sub-rules
- Patterns — Code examples with bad/good comparison
- STOP and Reconsider — Only in critical docs (1-2 per plugin)
- Common Mistakes — Edge cases and gotchas
- Resources — External links

### Plugin-Specific Depth

| Plugin | Reference Docs | STOP-Enabled Docs | Hook |
|--------|---------------|-------------------|------|
| askama | 5 | 1 (scope-debugging) | None |
| htmx-alpine | 7 + framework variants | 2 (alpine-state, accessibility) | None |
| mise | 4 | 1 (troubleshooting) | SessionStart |

### Cross-Plugin Coordination

Plugins are independent but aware of each other through soft pointers:

| From | To | Trigger | Reference |
|------|-----|---------|-----------|
| askama (htmx-partials.md) | htmx-alpine | Writing HTMX fragments | "See htmx-alpine for client patterns" |
| htmx-alpine (rust-axum.md) | askama | Writing axum handlers | "See askama for template composition" |
| mise (SessionStart hook) | rust-best-practices | Detects Cargo.toml | Suggests plugin if not installed |
| mise (SessionStart hook) | htmx-alpine | Detects htmx in package.json | Suggests plugin if not installed |

No hard dependencies — plugins install and function independently.

## Existing Patterns

Investigation of rust-best-practices plugin revealed the proven template structure:

**From `plugins/rust-best-practices/skills/rust-best-practices/SKILL.md`:**
- Task-to-reference lookup tables for lazy loading
- Error-to-reference lookup tables for debugging scenarios
- Anti-rationalization table with pattern→rationalization→fix columns
- Core principles as prose paragraphs (not bullet lists)

**From reference docs (`references/*.md`):**
- Consistent section structure across all 15 docs
- STOP sections only in high-impact docs (error-handling, async, unsafe)
- Code examples using visual distinction for bad/good patterns
- Minimal cross-linking between references (optional parenthetical hints only)

**From hooks (`hooks/`):**
- Fail-open design (never block operations on failure)
- Portable paths via `${CLAUDE_PLUGIN_ROOT}`
- 30-second timeout for formatting operations

This design follows all established patterns. No divergence from existing structure.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Askama Plugin Restructure

**Goal:** Transform two migrated skills into single comprehensive skill with reference docs and anti-rationalization structure.

**Components:**
- `plugins/askama/skills/askama/SKILL.md` — New unified skill (replaces askama-rust-templates + askama-debugging)
- `plugins/askama/skills/askama/references/template-syntax.md` — Askama syntax quick reference
- `plugins/askama/skills/askama/references/scope-debugging.md` — Module scope errors with STOP section
- `plugins/askama/skills/askama/references/filters.md` — Built-in and custom filter patterns
- `plugins/askama/skills/askama/references/inheritance.md` — Template extends, blocks, includes
- `plugins/askama/skills/askama/references/htmx-partials.md` — Fragment rendering for hx-swap, cross-references htmx-alpine
- `plugins/askama/.claude-plugin/plugin.json` — Update to reflect single skill
- Delete `plugins/askama/skills/askama-rust-templates/` and `plugins/askama/skills/askama-debugging/`

**TDD Validation:**
- Baseline test: Run pressure scenarios WITHOUT skill, document rationalizations
- Write skill: Address specific failures (type-to-string escape, Jinja2 idioms, safe filter)
- Pressure test: Validate skill resists rationalization under combined pressures
- Iterate: Close any loopholes discovered

**Pressure Scenarios:**
1. Type-to-String Escape (sunk cost + time): "Spent 20 minutes on 'method not found', PR due in 10 minutes, String fixes it"
2. Jinja2 Muscle Memory (authority + familiarity): "Team's Python devs suggest {% elif %} for consistency"
3. Safe Filter Shortcut (pragmatic + authority): "Tech lead says data is 'already validated server-side'"

**Dependencies:** None (first phase)

**Done when:** Single askama skill with 5 reference docs, anti-rationalization table in SKILL.md, STOP section in scope-debugging.md, all pressure tests pass
<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: HTMX-Alpine Plugin Expansion

**Goal:** Transform stub skill into comprehensive skill with reference docs, framework variants, and accessibility coverage.

**Components:**
- `plugins/htmx-alpine/skills/htmx-alpine/SKILL.md` — Expanded skill with anti-rationalization table
- `plugins/htmx-alpine/skills/htmx-alpine/references/htmx-requests.md` — hx-get/post/put/delete, hx-target, hx-swap
- `plugins/htmx-alpine/skills/htmx-alpine/references/alpine-state.md` — x-data, x-model, $store with STOP section for bloat
- `plugins/htmx-alpine/skills/htmx-alpine/references/integration.md` — Combining HTMX + Alpine, @htmx:* events
- `plugins/htmx-alpine/skills/htmx-alpine/references/feedback-patterns.md` — Loading indicators, error handling, optimistic UI
- `plugins/htmx-alpine/skills/htmx-alpine/references/realtime.md` — SSE and WebSocket extensions
- `plugins/htmx-alpine/skills/htmx-alpine/references/accessibility.md` — Focus management, ARIA with STOP section
- `plugins/htmx-alpine/skills/htmx-alpine/references/frameworks/rust-axum.md` — axum handlers, cross-references askama
- `plugins/htmx-alpine/skills/htmx-alpine/references/frameworks/django.md` — Django views + templates
- `plugins/htmx-alpine/skills/htmx-alpine/references/frameworks/go-templates.md` — Go html/template patterns

**TDD Validation:**
- Baseline test: Run pressure scenarios WITHOUT skill
- Write skill: Address fetch() escape, client state creep, accessibility shortcuts
- Pressure test: Validate resistance under combined pressures
- Iterate: Close loopholes

**Pressure Scenarios:**
1. fetch() Muscle Memory (familiarity + time): "Written this fetch() pattern 100 times, hx-* feels slower, feature due today"
2. Client State Creep (sunk cost + pragmatic): "Built wizard with Alpine x-data, now need persistence, more Alpine is quick"
3. Accessibility Shortcut (time + authority): "PM says audit is next quarter, modal works visually, focus management is extra work"

**Dependencies:** Phase 1 (for cross-plugin reference consistency)

**Done when:** Expanded htmx-alpine skill with 7 reference docs + 3 framework variants, STOP sections in alpine-state.md and accessibility.md, all pressure tests pass
<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: Mise Plugin Expansion

**Goal:** Transform stub skill into comprehensive skill with reference docs and SessionStart hook for toolchain detection.

**Components:**
- `plugins/mise/skills/mise/SKILL.md` — Expanded skill with anti-rationalization table
- `plugins/mise/skills/mise/references/configuration.md` — mise.toml structure, precedence, merge behavior
- `plugins/mise/skills/mise/references/tasks.md` — Task runner: dependencies, parallel execution, watch mode
- `plugins/mise/skills/mise/references/troubleshooting.md` — Activation context errors, PATH issues with STOP section
- `plugins/mise/skills/mise/references/ci-cd.md` — GitHub Actions, lockfiles, shims
- `plugins/mise/hooks/hooks.json` — SessionStart hook configuration
- `plugins/mise/hooks/detect-toolchain.sh` — Minimal toolchain detection script

**Hook Design (Minimal):**
- Only fires once per project (creates `.mise/.detected` marker)
- Silent if mise.toml exists
- Single-line suggestion if missing: "mise: No mise.toml found. Run `mise use rust@latest` to initialize."
- No plugin suggestions (too pushy)

**TDD Validation:**
- Baseline test: Run pressure scenarios WITHOUT skill
- Write skill: Address activation confusion, rate limit panic, local config commit
- Pressure test: Validate resistance under combined pressures
- Iterate: Close loopholes

**Pressure Scenarios:**
1. Activation Context Confusion (frustration + time): "CI failing 'command not found', adding mise activate because it works locally"
2. Rate Limit Panic (time + unfamiliarity): "CI fails with rate limit, removing mise unblocks immediately"
3. Local Config Commit (pragmatic + team): "Teammate asks to commit mise.local.toml so everyone gets dev tools"

**Dependencies:** None (can run parallel with Phase 2)

**Done when:** Expanded mise skill with 4 reference docs, SessionStart hook, STOP section in troubleshooting.md, all pressure tests pass
<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: Cross-Plugin Integration Testing

**Goal:** Verify cross-plugin references work correctly and plugins remain independently installable.

**Components:**
- Test askama htmx-partials.md references htmx-alpine correctly
- Test htmx-alpine rust-axum.md references askama correctly
- Test mise SessionStart hook suggests plugins appropriately
- Verify each plugin installs and functions without others present

**Dependencies:** Phases 1, 2, 3

**Done when:** All cross-references resolve, each plugin works independently, SessionStart hook is unobtrusive
<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: Version Bump and Documentation

**Goal:** Update plugin versions and documentation to reflect production-ready status.

**Components:**
- `plugins/askama/.claude-plugin/plugin.json` — Bump to 1.0.0
- `plugins/htmx-alpine/.claude-plugin/plugin.json` — Bump to 1.0.0
- `plugins/mise/.claude-plugin/plugin.json` — Bump to 1.0.0
- `plugins/askama/CLAUDE.md` — Update to reflect new structure
- `plugins/htmx-alpine/CLAUDE.md` — Update to reflect new structure
- `plugins/mise/CLAUDE.md` — Update to reflect new structure
- `.claude-plugin/marketplace.json` — Update versions
- `plugins/*/docs/design-notes.md` — Archive or remove (design complete)

**Dependencies:** Phase 4

**Done when:** All plugins at 1.0.0, documentation current, marketplace.json updated
<!-- END_PHASE_5 -->

## Additional Considerations

**TDD Approach for Skills:** This design requires running actual pressure tests during implementation, not just documenting them. Each phase includes specific scenarios with combined pressures (time + sunk cost + authority + familiarity). Skills are not complete until they resist rationalization under these conditions.

**Cross-Plugin Discovery:** The mise SessionStart hook suggests other plugins but does not require them. Users discover plugins organically through toolchain detection, not through aggressive prompting.

**Framework Variant Maintenance:** The htmx-alpine framework variants (rust-axum, django, go-templates) are optional reference docs. They can be added incrementally — the core skill is language-agnostic and complete without them. Initial implementation may include only rust-axum.md given the askama cross-reference.

**Token Efficiency:** All reference docs are lazy-loaded via lookup tables in SKILL.md. No reference doc is force-included. This keeps initial skill load lightweight while providing depth on demand.
