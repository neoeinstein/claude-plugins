---
name: askama-rust-templates
description: Use when writing new Askama templates or Template structs in Rust - covers idiomatic Rust syntax in templates, proper type usage instead of strings, and leveraging module scope for methods and traits
---

# Writing Askama Templates in Rust

## Overview

Askama templates are Rust code. Use Rust idioms: call methods on types, leverage Display implementations, pass references for non-Copy types.

**Core principle:** Templates share the module scope where `#[derive(Template)]` appears. Everything visible there is usable in the template.

## Quick Reference

| Task | Rust/Askama syntax |
|------|-------------------|
| Call method | `{{ event.title() }}` or `{{ event.title }}` (field) |
| Chain methods | `{{ value.trim().to_uppercase() }}` |
| Conditional | `{% if event.is_active() %}...{% endif %}` |
| Match on enum | `{% match status %}{% when Active %}...{% when Ended %}...{% endmatch %}` |
| For loop | `{% for item in items %}...{% endfor %}` |
| Option handling | `{% if let Some(x) = maybe_value %}{{ x }}{% endif %}` |
| Qualified path | `{{ MyEnum::Variant }}` or `{{ crate::types::Foo::bar() }}` |
| String concat | `{{ a ~ b ~ c }}` |
| Access tuple | `{{ pair.0 }}` |
| Loop index | `{{ loop.index }}` (1-based) or `{{ loop.index0 }}` (0-based) |
| First/last check | `{% if loop.first %}...{% endif %}` |
| Apply filter | `{{ value | filter }}` or `{{ value | filter(arg) }}` |

## Idiomatic Patterns

**Pass references for non-Copy, values for Copy:**
```rust
pub struct MyTemplate<'a> {
    pub title: &'a str,               // Reference - non-Copy
    pub event: &'a MagicEventHeader,  // Reference - complex type
    pub current_players: u32,         // Copy - just copy it
    pub is_active: bool,              // Copy - just copy it
}
```

**Keep rich types, implement Display:**
```rust
pub struct MyTemplate {
    pub status: EventStatus,  // impl Display for EventStatus
}

// Template uses it directly:
// <span class="{{ status.css_class() }}">{{ status }}</span>
```

**Use methods over pre-computing strings:**
```rust
impl EventDisplayData {
    pub fn entry_fee_text(&self) -> Option<String> { ... }
}

// In template:
// {% if let Some(fee) = event.entry_fee_text() %}{{ fee }}{% endif %}
```

## Template Inheritance

**Base template (base.html):**
```html
<!DOCTYPE html>
<html>
<head>{% block extra_styles %}{% endblock %}</head>
<body>
    {% block content %}{% endblock %}
</body>
</html>
```

**Child template:**
```html
{% extends "base.html" %}

{% block content %}
<h1>My Page</h1>
{% endblock %}
```

**Including subtemplates:**
```html
{% include "event_item.html" %}
```

Included templates share the parent's context - all variables are accessible.

**Pre-rendered HTML (safe filter):**

When passing already-rendered HTML as a string field:
```rust
let inner_html = InnerTemplate { ... }.render()?;
let outer = OuterTemplate { content: inner_html };
```

```html
{{ content | safe }}
```

Use `safe` only for trusted content, never user input.

## Match Expressions

```html
{% match status %}
    {% when EventStatus::Active %}
        <span class="active">Live</span>
    {% when EventStatus::Scheduled %}
        <span class="scheduled">Upcoming</span>
    {% when EventStatus::Ended %}
        <span class="ended">Finished</span>
{% endmatch %}
```

For Option:
```html
{% match maybe_value %}
    {% when Some with (val) %}
        {{ val }}
    {% when None %}
        N/A
{% endmatch %}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `{% elif %}` | Use `{% else if %}` |
| Expecting Python truthiness | Use explicit `{% if items.is_empty() %}` or `{% if !items.is_empty() %}` |
| Using Jinja2 `{% raw %}` | Use `{% raw %}...{% endraw %}` (same syntax, but check docs) |

## Reference

- [Askama Template Syntax](https://askama.readthedocs.io/en/stable/template_syntax.html)
- [Askama Filters](https://askama.readthedocs.io/en/stable/filters.html)
