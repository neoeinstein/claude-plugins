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
| Configuring Clippy, setting up lints | `references/clippy-config.md` |
| Adding `#[allow]`/`#[expect]` annotations, dead code warnings | `references/clippy-config.md` |
| Structuring code, applying design patterns | `references/patterns.md` |
| Organizing modules, separating pure logic from I/O | `references/fcis.md` |
| Unsure how to use a crate, need documentation | `references/finding-docs.md` |
| Writing doc comments, examples in docs | `references/writing-docs.md` |
| Writing or running tests, choosing test strategy | `references/testing.md` |
| Using async/await, tokio, channels, spawn, timeout | `references/async.md` |
| Choosing mutex types, graceful shutdown, cancellation | `references/async.md` |
| Lifetime annotations, `'static`, HRTBs | `references/lifetimes.md` |
| Writing or reviewing unsafe code, FFI, MaybeUninit | `references/unsafe.md` |
| `Send`/`Sync` bounds, thread safety, Arc/Mutex | `references/send-sync.md` |
| Serde, JSON serialization, derive attributes | `references/serde.md` |

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

## Core Principles

**Type Safety:** Prefer newtypes over primitives. `UserId(String)` > `String`. Identifiers should be strings (or KSUIDs/UUIDs), not integers — you don't do math on IDs.

**Error Handling:** `thiserror` for libraries, `color_eyre` for applications. Reserve `.expect()` for initialization only. **Never** `.unwrap()` or `.expect()` in production runtime code.

**Enums over Bools:** `enum Visibility { Public, Private }` > `is_public: bool`.

**Make Illegal States Unrepresentable:** Use the type system to prevent invalid data.

**Validate at Construction:** Use `TryFrom`/newtypes with validation in constructors. A `Port(u16)` that rejects 0 is better than validating port values at every call site. Once constructed, the value is always valid.

**Separate Pure Logic from I/O (FCIS):** Organize modules so pure domain logic is separate from I/O and side effects. Pure `domain` modules contain types, validation, and business rules. `service` modules handle I/O, persistence, and external calls. See `references/fcis.md`.

**Prefer Minimal Visibility:** Start with the most restrictive visibility. Use `pub(super)` for parent-module access, `pub(crate)` for crate-internal access, and `pub` only when external crates need it. Apply the same discipline to struct fields.

## STOP — Anti-Rationalization Table

Before writing code that matches these patterns, STOP and reconsider.

| You're about to... | Common rationalization | What to do instead |
|---------------------|------------------------|--------------------|
| Use `.unwrap()` outside tests | "It can't fail here" / "I'll fix it later" | Use `?`, `.expect("reason")`, or handle the error. Load `references/error-handling.md`. |
| Skip creating a newtype for a domain value | "It's just a String" / "Too much boilerplate" | Create the newtype. The boilerplate is the point — it prevents bugs. Load `references/type-safety.md`. |
| Skip input validation on a public constructor | "Callers will pass valid data" | Add `TryFrom` or a `fn new() -> Result<Self, E>`. Validate at construction, not at use. |
| Hold a `MutexGuard` across `.await` | "The lock is quick" / "It won't deadlock" | Restructure: clone the data, drop the guard, then await. Load `references/async.md`. |
| Write `unsafe` without a `// SAFETY:` comment | "It's obviously safe" / "I'll document later" | Write the SAFETY comment first. If you can't articulate the invariants, the code isn't safe. Load `references/unsafe.md`. |
| Use `bool` for a two-state concept | "An enum is overkill" | Create the enum. Bools are meaningless at call sites: `set_active(true)` vs `set_status(Status::Active)`. Load `references/enum-design.md`. |
| Add a catch-all `_ =>` to a match on your own enum | "I don't want to update every match" | That's exactly why you should — exhaustive matching catches forgotten variants at compile time. |
| Use `mem::transmute` | "I know the layout" | You probably don't. Use `from_ne_bytes`, `bytemuck`, or `zerocopy` instead. Load `references/unsafe.md`. |
| Add `#[allow(dead_code)]` | "Conditionally dead — used in tests" / "Not used yet" | If only used in tests, the code IS dead — delete it (or the tests). Use `#[expect(dead_code)]` for interim work, never `#[allow]`. Load `references/clippy-config.md`. |
| Leave `#[expect(dead_code)]` at end of task | "Field exists but not yet used" / "Will be wired up later" | Clean it up NOW. Either wire it up or remove it. `expect(dead_code)` is a WIP marker, not a permanent annotation. |

## Authoritative Resources

- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/) — Definitive guide from Rust library team
- [Clippy Lints](https://rust-lang.github.io/rust-clippy/master/index.html) — 750+ lints, searchable
- [Rust Design Patterns](https://rust-unofficial.github.io/patterns/) — Community patterns and anti-patterns
- [Effective Rust](https://effective-rust.com/) — 35 specific ways to improve your code
