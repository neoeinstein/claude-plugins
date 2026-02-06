# Askama Template Syntax

## When to Use This Reference

- Learning Askama template syntax for the first time
- Converting templates from Jinja2/Python
- Needing quick syntax reference for loops, conditionals, match
- Debugging whitespace issues in template output

## Quick Reference

| Syntax | Askama | Note |
|--------|--------|------|
| Expression | `{{ value }}` | Rust expressions, auto-escaped |
| Statement | `{% if %}...{% endif %}` | Control flow |
| Comment | `{# comment #}` | Not rendered |
| Else-if | `{% else if %}` | NOT `{% elif %}` |
| Logical AND | `&&` or `and` | Both work |
| Logical OR | `\|\|` or `or` | Both work |
| Logical NOT | `!` or `not` | Both work |
| String concat | `{{ a ~ b }}` | Tilde operator |

## The Rule

Askama uses Jinja2-like syntax but compiles to Rust. Key differences from Jinja2:
- `{% else if %}` not `{% elif %}`
- No Python truthiness — use explicit `.is_empty()` or `!items.is_empty()`
- Rust operator precedence applies
- Method calls use Rust syntax: `{{ value.method() }}`

## Patterns

### Conditionals

```html
{% if user.is_admin() %}
    <span class="admin">Admin</span>
{% else if user.is_moderator() %}
    <span class="mod">Moderator</span>
{% else %}
    <span class="user">User</span>
{% endif %}
```

### Loops

```html
{% for item in items %}
    <li class="{% if loop.first %}first{% endif %}">
        {{ loop.index }}. {{ item.name }}
    </li>
{% endfor %}
```

Loop variables:
- `loop.index` — 1-based index
- `loop.index0` — 0-based index
- `loop.first` — true on first iteration
- `loop.last` — true on last iteration

### Match Expressions

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

For Option types:
```html
{% match maybe_value %}
    {% when Some with (val) %}
        {{ val }}
    {% when None %}
        N/A
{% endmatch %}
```

### If-Let

```html
{% if let Some(fee) = event.entry_fee_text() %}
    <span class="fee">{{ fee }}</span>
{% endif %}
```

### Whitespace Control

Use `-` to trim whitespace:
```html
{%- if condition -%}
    trimmed
{%- endif -%}
```

- `{%-` trims whitespace before
- `-%}` trims whitespace after
- Apply to both opening and closing tags for full control

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `{% elif %}` | Compile error: unexpected token | Use `{% else if %}` |
| `{% if items %}` | Compile error: expected bool | Use `{% if !items.is_empty() %}` |
| Missing whitespace trim | Extra newlines in output | Use `{%-` and `-%}` |
| `{{ value + other }}` with strings | Type error | Use `{{ value ~ other }}` for concat |

## Resources

- [Template Syntax Reference](https://askama.readthedocs.io/en/stable/template_syntax.html)
- [Whitespace Control](https://askama.readthedocs.io/en/stable/template_syntax.html#whitespace-control)
