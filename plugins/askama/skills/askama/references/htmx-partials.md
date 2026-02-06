# HTMX Partials with Askama

## When to Use This Reference

- Rendering HTML fragments for HTMX `hx-swap` responses
- Setting up Axum handlers that return template fragments
- Using block-specific rendering for partial updates
- Integrating Askama with htmx-driven UIs

## Quick Reference

| Pattern | Use Case | Askama Feature |
|---------|----------|----------------|
| Block rendering | Return specific block only | `#[template(block = "name")]` |
| Fragment template | Dedicated partial | Separate Template struct |
| Inline response | Simple HTML | `Html(String)` with render |

## The Rule

HTMX expects HTML fragments, not full pages. Askama supports this via block-specific rendering: annotate your Template with `block = "name"` to render only that block.

**For HTMX integration with Axum**, see the htmx-alpine plugin for client-side patterns. This reference covers server-side Askama rendering only.

## Patterns

### Block-Specific Rendering

Define reusable blocks in your template:
```html
<!-- templates/todos.html -->
{% block todo_item %}
<li id="todo-{{ item.id }}" class="{% if item.done %}done{% endif %}">
    {{ item.title }}
</li>
{% endblock %}

{% block todo_list %}
<ul id="todo-list">
    {% for item in items %}
        {% include "todo_item" %}
    {% endfor %}
</ul>
{% endblock %}
```

Create a fragment-specific Template struct:
```rust
#[derive(Template)]
#[template(path = "todos.html", block = "todo_item")]
struct TodoItemFragment<'a> {
    item: &'a TodoItem,
}
```

### Axum Handler for Fragments

```rust
use askama::Template;
use axum::response::Html;

#[derive(Template)]
#[template(path = "todos.html", block = "todo_item")]
struct TodoItemFragment<'a> {
    item: &'a TodoItem,
}

async fn add_todo(
    State(db): State<Database>,
    Form(input): Form<NewTodo>,
) -> Html<String> {
    let item = db.create_todo(input).await;
    let fragment = TodoItemFragment { item: &item };
    Html(fragment.render().unwrap())
}
```

### Full Page vs Fragment

Use the same template for both full page and fragment responses:

```rust
// Full page render
#[derive(Template)]
#[template(path = "todos.html")]
struct TodosPage {
    items: Vec<TodoItem>,
}

// Fragment render (same template, specific block)
#[derive(Template)]
#[template(path = "todos.html", block = "todo_list")]
struct TodoListFragment {
    items: Vec<TodoItem>,
}
```

### Using askama_axum

With `askama_axum`, templates implement `IntoResponse`:

```rust
use askama_axum::Template;

#[derive(Template)]
#[template(path = "item.html")]
struct ItemTemplate {
    item: Item,
}

async fn get_item(Path(id): Path<i32>) -> ItemTemplate {
    let item = fetch_item(id).await;
    ItemTemplate { item }
}
```

No need to call `.render()` or wrap in `Html`.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Returning full page to HTMX | Page content duplicated | Use `block = "name"` attribute |
| Missing block in template | Empty response | Define the block in template file |
| Wrong block name | Compile error or empty | Check block name matches exactly |

## Integration Notes

**This reference covers Askama (server-side).** For HTMX client-side patterns (`hx-get`, `hx-swap`, `hx-target`), loading indicators, and Alpine.js integration, see the **htmx-alpine** plugin.

Typical flow:
1. Client sends HTMX request (`hx-post="/todos"`)
2. Axum handler processes request
3. Askama renders block fragment
4. HTMX swaps response into target element

## Resources

- [Askama Block Rendering](https://askama.readthedocs.io/en/stable/creating_templates.html)
- [askama_axum Crate](https://docs.rs/askama_axum)
- [HTMX Template Fragments Essay](https://htmx.org/essays/template-fragments/)
