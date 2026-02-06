---
name: askama
description: Use when writing Askama templates in Rust to ensure idiomatic patterns, fix compile errors by understanding module scope, and avoid common anti-patterns from Jinja2 muscle memory
---

# Askama Templates in Rust

## Overview

Askama templates are Rust code compiled at build time. Templates share the module scope where `#[derive(Template)]` appears — everything visible there is usable in the template.

## Quick Reference - What to Load

| If you're... | Load |
|--------------|------|
| Learning Askama syntax, conditionals, loops, match | `references/template-syntax.md` |
| Seeing "method not found" or "type not found" errors | `references/scope-debugging.md` |
| Tempted to convert a type to String to fix an error | `references/scope-debugging.md` |
| Using or creating filters, the `safe` filter | `references/filters.md` |
| Using template extends, blocks, includes | `references/inheritance.md` |
| Rendering HTML fragments for HTMX hx-swap | `references/htmx-partials.md` |

## Error Message → Reference

| If you see... | Load |
|---------------|------|
| "method not found in `[TypeName]`" | `references/scope-debugging.md` |
| "cannot find type `[TypeName]` in this scope" | `references/scope-debugging.md` |
| "trait bound not satisfied" in template context | `references/scope-debugging.md` |
| Unexpected whitespace in output | `references/template-syntax.md` (whitespace control) |

## Core Principles

**Templates Are Rust Code:** Askama templates compile to Rust. Use Rust idioms: call methods on types, leverage Display implementations, pattern match with `{% match %}`. Don't pre-compute strings in Rust when the template can call the method directly.

**Module Scope Determines Visibility:** The template can only access what's visible in the module where `#[derive(Template)]` appears. If a method isn't found, the trait providing it isn't imported — fix the imports, don't convert to String.

**Keep Rich Types:** Pass domain types to templates, not stringified versions. A template receiving `EventStatus` can call `.css_class()`, `.display_name()`, and match on variants. A template receiving a String can only display it.

**Compile-Time Safety:** Template errors surface at `cargo build`, not at runtime. This is a feature. Don't fight it by converting everything to strings — embrace it by fixing scope issues properly.

**Validate Before Rendering:** The `safe` filter bypasses escaping. Only use it for content you control (pre-rendered HTML from your own code). Never use it on user input.

## STOP — Anti-Rationalization Table

Before writing code that matches these patterns, STOP and reconsider.

| You're about to... | Common rationalization | What to do instead |
|--------------------|------------------------|--------------------|
| Convert a type to String to fix "method not found" | "It's faster than fixing the scope" / "I'll clean it up later" | Import the trait in the template's module. The 20 minutes you spent is sunk cost — don't compound it. Load `references/scope-debugging.md`. |
| Use `{% elif %}` (Jinja2 syntax) | "It's more familiar" / "Team uses Python too" | Use `{% else if %}`. Askama is Rust, not Jinja2. The compile error is telling you this. |
| Apply `safe` filter to user-controlled data | "It's already validated server-side" / "We trust this field" | Never trust, always escape. If you need HTML, render it through a controlled template, not `{{ raw_html \| safe }}`. Load `references/filters.md`. |
| Skip using `{% match %}` for an enum | "If/else is simpler" | Match is exhaustive — the compiler catches forgotten variants. If/else silently ignores new cases. |
| Pre-format everything in Rust before passing to template | "Templates should just display" | Templates can call methods. Keep logic in types, let templates use it. |
| Add `#[allow(dead_code)]` to Template fields | "The template uses it but Rust doesn't see it" | This is expected. Use `#[expect(dead_code)]` instead so you're prompted to remove it if the field becomes truly unused. |

## Authoritative Resources

- [Askama Book](https://askama.rs/) — Official documentation
- [Askama Template Syntax](https://askama.readthedocs.io/en/stable/template_syntax.html) — Syntax reference
- [Askama Filters](https://askama.readthedocs.io/en/stable/filters.html) — Built-in and custom filters
- [askama on docs.rs](https://docs.rs/askama/latest/askama/) — API documentation
