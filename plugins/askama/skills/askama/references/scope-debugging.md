# Debugging Askama Scope Errors

## When to Use This Reference

- Template fails to compile with "method not found" or "type not found"
- Tempted to convert a rich type to String to "fix" an error
- Extension trait methods aren't available in template
- Need to understand how Askama's module scope model works

## Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| "method not found in `Type`" | Trait not in scope | Import trait where Template struct is defined |
| "cannot find type `Type`" | Type not in scope | Add `use` statement to template module |
| "trait bound not satisfied" | Missing trait impl | Check trait is implemented and in scope |

## The Rule

Askama compiles templates into Rust code within the module where your `#[derive(Template)]` struct is defined. The template inherits that module's scope.

**Everything the template can access must be visible at the struct's definition site.**

This includes:
- Types used in expressions
- Traits whose methods are called
- Functions called directly
- Constants and statics referenced

## STOP and Reconsider

**Before converting a type to String to fix a scope error, STOP.**

You've likely spent time debugging. The String conversion seems like a quick fix. It's not.

| Situation | Why String is wrong | What to do |
|-----------|---------------------|------------|
| "Spent 20 min, PR due soon" | Sunk cost. String hides the real issue. | Take 5 more minutes to import the trait. Future you will thank you. |
| "It works with .to_string()" | You've lost type safety and methods. | Keep the type. Fix the import. |
| "The type is complex" | Complex types have useful methods. String has none. | Import what you need. The template can use all those methods. |

**The correct fix is always to adjust the module scope, not to stringify.**

## Patterns

### Trait Method Not Found

**Wrong — converting to String:**
```rust
pub struct MyTemplate {
    pub status: String,  // Was EventStatus
}

// In handler:
MyTemplate {
    status: event.status.to_string(),  // Lost methods
}
```

**Right — import the trait:**
```rust
use crate::models::EventStatusExt;  // Trait with display methods

pub struct MyTemplate {
    pub status: EventStatus,  // Keep the rich type
}

// Template can now call:
// {{ status.css_class() }}
// {{ status.display_name() }}
```

### Type Not In Scope

**Add import to template module:**
```rust
// In the module where Template is derived:
use crate::types::EventStatus;

#[derive(Template)]
#[template(path = "event.html")]
pub struct EventTemplate {
    pub status: EventStatus,
}
```

**Or use qualified path in template:**
```html
{% match status %}
    {% when crate::types::EventStatus::Active %}
        ...
{% endmatch %}
```

### Accessing Items from Parent/Crate

```html
<!-- Same module -->
{{ self::helper_function() }}

<!-- Parent module -->
{{ super::parent_function() }}

<!-- Crate root -->
{{ crate::utils::format_date(date) }}
```

## Debugging Flow

1. **Locate the Template struct** — find where `#[derive(Template)]` is declared
2. **Check module scope** — what's imported/visible in that module?
3. **Identify the missing piece:**
   - Type not found → add `use` statement
   - Method not found → import the trait that defines it
   - Associated function → use qualified path in template

## Common Mistakes

| Mistake | Why it happens | Fix |
|---------|----------------|-----|
| Convert to String | Path of least resistance | Import trait, keep type |
| Use `format!()` in Rust | Unfamiliarity with template expressions | Let template use Display |
| Copy Jinja2 idioms | Cross-language confusion | Use Rust methods, not filters |

## Resources

- [Askama Template Syntax](https://askama.readthedocs.io/en/stable/template_syntax.html)
- [Rust Module System](https://doc.rust-lang.org/book/ch07-00-managing-growing-projects-with-packages-crates-and-modules.html)
