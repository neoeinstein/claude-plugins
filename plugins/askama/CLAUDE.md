# askama Plugin

Last verified: 2026-02-05

## Purpose

Guidance for writing and debugging Askama templates in Rust. Emphasizes fixing scope errors properly (not converting to String) and avoiding Jinja2 muscle memory anti-patterns.

## Contracts

- **Exposes**: `askama:askama` skill with 5 reference docs
- **Guarantees**: Skills are standalone, no hooks or external dependencies. Reference docs are lazy-loaded via SKILL.md lookup tables.
- **Expects**: User working with Askama crate in a Rust project

## Key Decisions

- **Unified skill over multiple skills**: Consolidated `askama-rust-templates` and `askama-debugging` into single `askama` skill following rust-best-practices template structure.
- **Anti-rationalization emphasis**: STOP section in SKILL.md and scope-debugging.md addresses the common pattern of converting types to String under time pressure.
- **Cross-plugin soft pointer**: htmx-partials.md references htmx-alpine plugin for client-side patterns without creating hard dependency.

## Key Files

- `skills/askama/SKILL.md` — Main skill with lookup tables and anti-rationalization table
- `skills/askama/references/template-syntax.md` — Syntax quick reference, Jinja2 differences
- `skills/askama/references/scope-debugging.md` — Module scope model, STOP section for String conversion
- `skills/askama/references/filters.md` — Built-in and custom filters, safe filter security
- `skills/askama/references/inheritance.md` — extends, blocks, includes
- `skills/askama/references/htmx-partials.md` — Fragment rendering for HTMX

## Invariants

- Every reference doc must be loadable independently
- SKILL.md lookup tables must cover all reference docs
- STOP sections only in SKILL.md and scope-debugging.md (high-impact locations)
