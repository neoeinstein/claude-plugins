# htmx-alpine Plugin

Last verified: 2026-02-05

## Purpose

Patterns for building server-driven web applications with HTMX and Alpine.js. Language-agnostic guidance focused on the interaction model, with framework-specific reference docs for common stacks.

## Contracts

- **Exposes**: `htmx-alpine:htmx-alpine` skill with 7 reference docs + 1 framework variant
- **Guarantees**: Skill is standalone, no hooks. Reference docs are lazy-loaded via SKILL.md lookup tables. Core patterns are framework-agnostic.
- **Expects**: User working with HTMX and/or Alpine.js in any server-side framework

## Key Decisions

- **Server is source of truth**: Core principle emphasized throughout. Alpine state is UI-only.
- **Accessibility not optional**: Dedicated reference doc with STOP section. Focus management, ARIA live regions, keyboard navigation.
- **Framework variants as reference docs**: rust-axum.md in frameworks/ subdirectory. Additional variants (Django, Go) can be added incrementally.
- **Cross-plugin soft pointer**: rust-axum.md references askama plugin for template patterns without hard dependency.

## Key Files

- `skills/htmx-alpine/SKILL.md` — Main skill with lookup tables and anti-rationalization table
- `skills/htmx-alpine/references/htmx-requests.md` — hx-get/post, targeting, swap strategies
- `skills/htmx-alpine/references/alpine-state.md` — x-data/x-model, STOP section for state bloat
- `skills/htmx-alpine/references/integration.md` — @htmx:* events, coordinating both libraries
- `skills/htmx-alpine/references/feedback-patterns.md` — Loading indicators, error handling
- `skills/htmx-alpine/references/realtime.md` — SSE and WebSocket extensions
- `skills/htmx-alpine/references/accessibility.md` — ARIA, focus management, STOP section
- `skills/htmx-alpine/references/frameworks/rust-axum.md` — Axum + Askama integration

## Invariants

- Every reference doc must be loadable independently
- SKILL.md lookup tables must cover all reference docs
- STOP sections only in alpine-state.md and accessibility.md (high-impact locations)
- Framework variants are optional and independently loadable
