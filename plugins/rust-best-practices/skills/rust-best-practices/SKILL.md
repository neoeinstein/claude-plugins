---
name: rust-best-practices
description: Use when writing, reviewing, or modifying Rust code to ensure idiomatic patterns, proper error handling, type safety, and adherence to community standards
---

# Rust Best Practices

## Overview

Reference guide for writing idiomatic, safe, and maintainable Rust code. Load topic-specific references based on your current task.

## Quick Reference - What to Load

| If you're... | Load |
|--------------|------|
| Creating types, seeing `String` or `i32` where domain types fit | `references/type-safety.md` |
| Handling errors, seeing `.unwrap()` or `.expect()` | `references/error-handling.md` |
| Using `bool` parameters, designing enums | `references/enum-design.md` |
| Designing public APIs, builders, trait implementations | `references/api-design.md` |
| Adding a `pub use`, choosing where a public item lives, re-exports, preludes | `references/re-exports.md` |
| Choosing the lint set or the unsafe policy | `references/lint-setup.md` |
| Cargo workspace setup: inheriting package/lints/dependencies across members, `[workspace.*]`, version drift, scaffolding a new member crate | `references/workspace.md` |
| A lint fired; considering suppression; `#[allow]`/`#[expect]`; `dead_code`; `unfulfilled_lint_expectations` | `references/responding-to-lints.md` |
| Structuring code, applying design patterns | `references/patterns.md` |
| Organizing modules, separating pure logic from I/O | `references/fcis.md` |
| Unsure how to use a crate, need documentation | `references/finding-docs.md` |
| Writing or running tests, choosing test strategy | `references/testing.md` |
| Using async/await, tokio, channels, spawn, timeout | `references/async.md` |
| Choosing mutex types, graceful shutdown, cancellation | `references/async.md` |
| Lifetime annotations, `'static`, HRTBs | `references/lifetimes.md` |
| Writing or reviewing unsafe code, FFI, MaybeUninit | `references/unsafe.md` |
| `Send`/`Sync` bounds, thread safety, Arc/Mutex | `references/send-sync.md` |
| Serde, JSON serialization, derive attributes | `references/serde.md` |
| Building a JSON/message payload you own — reaching for `serde_json::json!` or `serde_json::to_vec` of an ad-hoc value | `references/serde.md` |
| Choosing a serialization stack (serde vs facet) | `references/serde.md` |
| `dead_code` on `Deserialize` structs, DTO dead fields | `references/serde.md` |
| Using aliri_braid, seeing `new()` conflicts or `Infallible` errors | `references/type-safety.md` |

Deep facet-ecosystem work (`#[derive(Facet)]`, facet-json/csv, figue, strid, rediff) is covered by the separate `facet` skill, which loads on its own triggers — never reference it as a `references/` path.

## Error Message → Reference

| If you see... | Load |
|---------------|------|
| "future cannot be sent between threads safely" | `references/send-sync.md` + `references/async.md` |
| "cannot be shared between threads safely" | `references/send-sync.md` |
| "borrowed value does not live long enough" | `references/lifetimes.md` |
| "does not live long enough" | `references/lifetimes.md` |
| "missing lifetime specifier" | `references/lifetimes.md` |
| "the trait `Send` is not implemented" | `references/send-sync.md` |
| "holding across an await point" | `references/async.md` |
| "`MutexGuard` held across await" | `references/async.md` |
| "higher-ranked lifetime error" | `references/lifetimes.md` (HRTBs) |
| "cannot infer type" with serde | `references/serde.md` |
| "duplicate definitions with name `new`" near a braid type | `references/type-safety.md` (aliri_braid gotchas) |

## Core Principles

**Type Safety:** Prefer newtypes over primitives. `UserId(String)` > `String`. Identifiers should be strings (or KSUIDs/UUIDs), not integers — you don't do math on IDs.

**Error Handling:** `thiserror` for libraries, `color_eyre` for applications. Reserve `.expect()` for initialization only. **Never** `.unwrap()` or `.expect()` in production runtime code.

**Enums over Bools:** `enum Visibility { Public, Private }` > `is_public: bool`.

**Make Illegal States Unrepresentable:** Use the type system to prevent invalid data.

**Validate at Construction:** Use `TryFrom`/newtypes with validation in constructors. A `Port(u16)` that rejects 0 is better than validating port values at every call site. Once constructed, the value is always valid.

**Separate Pure Logic from I/O (FCIS):** Organize modules so pure domain logic is separate from I/O and side effects. Pure `domain` modules contain types, validation, and business rules. `service` modules handle I/O, persistence, and external calls. See `references/fcis.md`.

**Prefer Minimal Visibility:** Start with the most restrictive visibility. Use `pub(super)` for parent-module access, `pub(crate)` for crate-internal access, and `pub` only when external crates need it. Apply the same discipline to struct fields.

**Suppress with `#[expect]`, never `#[allow]` in source.** `allow` belongs only in `Cargo.toml` config; source uses `#[expect(lint, reason = "…")]` only. See `references/lint-setup.md` (config) and `references/responding-to-lints.md` (mechanics).

## STOP — Anti-Rationalization Table

Before writing code that matches these patterns, STOP and reconsider.

| You're about to... | Common rationalization | What to do instead |
|---------------------|------------------------|--------------------|
| Add a catch-all `_ =>` to a match on your own enum | "I don't want to update every match" | That's exactly why you should — exhaustive matching catches forgotten variants at compile time. |
| Use `mem::transmute` | "I know the layout" | You probably don't. Use `from_ne_bytes`, `bytemuck`, or `zerocopy` instead. Load `references/unsafe.md`. |
| Suppress a lint instead of fixing the code | "It's just a style lint" / "more readable this way" | **Fix the code.** Suppression is only for structural constraints you can't change. Load `references/responding-to-lints.md`. |
| Add `#[allow(dead_code)]` | "Conditionally dead — used in tests" / "Not used yet" | If only tests use it, it IS dead — delete it. `#[expect(dead_code, reason = "…")]` is for interim work only. Load `references/responding-to-lints.md`. |
| Add a module-wide `#![expect(…)]` or suppress `unfulfilled_lint_expectations` | "One suppression covers the module" / "the expectation warning is noise" | The warning means an `#[expect]` is stale or mis-scoped — delete it or `cfg_attr` it to the cfg where the lint fires. Load `references/responding-to-lints.md`. |
| Re-export an item at an additional public path | "Shorter import" / "easier to find" | Every public item gets ONE canonical path; root promotion is for marquee items only. Load `references/re-exports.md`. |
| Declare a dependency version in a workspace member crate | "Only this crate uses it" | Hoist to `[workspace.dependencies]`; per-member versions drift and can duplicate in the tree. Load `references/workspace.md`. |

## Authoritative Resources

- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/) — the library team's design conventions
- [Clippy lint index](https://rust-lang.github.io/rust-clippy/master/index.html) — searchable list of every lint
- [Microsoft Pragmatic Rust Guidelines](https://microsoft.github.io/rust-guidelines/) — agent-consultable corpus (`agents/all.txt`)
