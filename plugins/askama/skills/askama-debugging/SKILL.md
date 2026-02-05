---
name: askama-debugging
description: Use when Askama templates fail to compile, types or methods aren't found, or reverting to string workarounds instead of fixing scope - guides fixing template errors by understanding Askama's Rust module scope model
---

# Debugging Askama Template Errors

## Overview

Askama templates compile as Rust code using the exact scope where `#[derive(Template)]` appears. Fix missing symbols by adjusting that module's imports, not by working around with strings.

**Core principle:** The template can only use what's visible in the module where the Template struct is defined.

## When to Use

- Template fails to compile with "type not found" or "method not found"
- Tempted to convert a rich type to String to "fix" an error
- Extension trait methods aren't available in template

## Anti-Patterns to Avoid

| Anti-pattern | Why it happens | Correct approach |
|--------------|----------------|------------------|
| Convert to String before passing to template | "Method not found" on the type | Import the trait or use fully-qualified path |
| Use `format!()` outside template | Unfamiliarity with template expressions | Let template handle formatting via Display or methods |
| Revert to primitive strings when type fails | Path of least resistance | Add type/trait to module scope |
| Copy Jinja2/Python idioms | Cross-language confusion | Use Rust syntax: methods, not filters for most things |

## Debugging Flow

1. **Locate the Template struct** - Find where `#[derive(Template)]` is declared
2. **Check module scope** - What's imported/visible in that module?
3. **Identify the missing piece:**
   - Type not found -> Add `use` statement to module
   - Method not found -> Import the extension trait
   - Associated function -> Use fully-qualified path in template

## Common Fixes

**Method not found on type:**
```rust
// In templates.rs where Template is derived:
use crate::models::MyExtensionTrait;  // Now methods are available in template
```

**Type not accessible:**
```rust
// Option 1: Import in template module
use crate::types::EventStatus;

// Option 2: Use qualified path in template
// {{ crate::types::EventStatus::Active }}
```

**Don't do this:**
```rust
// Converting to String to "fix" the problem
pub struct MyTemplate {
    pub status: String,  // Was EventStatus, but "method not found"
}

// Creating the template:
MyTemplate {
    status: event.status.to_string(),  // Lost type safety
}
```

**Do this instead:**
```rust
// Keep the rich type, fix the scope
pub struct MyTemplate {
    pub status: EventStatus,
}

// In the same module, import what's needed:
use crate::models::EventStatusExt;  // Extension trait with display methods
```

## Creating Custom Filters

Use filters for reusable transformations across templates when you can't modify the type.

**Filter module setup:**
```rust
mod filters {
    use std::fmt::Display;

    // Filters require value + Values parameter, return askama::Result
    pub fn format_currency(
        cents: &i32,
        _: &dyn askama::Values,
    ) -> askama::Result<String> {
        Ok(format!("${}.{:02}", cents / 100, cents.abs() % 100))
    }

    // Additional arguments come after the Values parameter
    pub fn pluralize(
        count: &i32,
        _: &dyn askama::Values,
        singular: &str,
        plural: &str,
    ) -> askama::Result<String> {
        Ok(if *count == 1 { singular } else { plural }.to_string())
    }
}
```

**Using in template:**
```html
<span>{{ price|format_currency }}</span>
<span>{{ count }} {{ count|pluralize("item", "items") }}</span>
```

**Common filter mistakes:**
- Forgetting `askama::Result` return type
- Missing the `&dyn askama::Values` second parameter
- Filter module not in scope where Template is derived

## Reference

- [Askama Template Syntax](https://askama.readthedocs.io/en/stable/template_syntax.html)
- [Askama Filters](https://askama.readthedocs.io/en/stable/filters.html)
