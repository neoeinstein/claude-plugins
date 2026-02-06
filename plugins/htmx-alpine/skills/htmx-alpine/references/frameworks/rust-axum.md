# HTMX with Axum and Askama

## When to Use This Reference

- Building HTMX-driven apps with Axum web framework
- Returning HTML fragments from Axum handlers
- Integrating Askama templates with HTMX patterns
- Setting HX-Trigger response headers

## Quick Reference

| Pattern | Axum Approach |
|---------|---------------|
| Return HTML fragment | `Html(template.render().unwrap())` |
| Return full page | Template with `askama_axum::IntoResponse` |
| Send HX-Trigger | Response header via extension |
| Handle HX-Request | Check `HX-Request` header |

## The Rule

Axum handlers return HTML. Askama templates render that HTML. HTMX controls what happens with it on the client.

**For Askama template patterns, see the askama plugin.** This reference covers only the Axum handler side of the integration.

## Patterns

### Basic Fragment Handler

```rust
use axum::{extract::Path, response::Html};
use askama::Template;

#[derive(Template)]
#[template(path = "item.html")]
struct ItemTemplate {
    item: Item,
}

async fn get_item(Path(id): Path<i32>) -> Html<String> {
    let item = fetch_item(id).await;
    let template = ItemTemplate { item };
    Html(template.render().unwrap())
}
```

### Block-Specific Rendering

Render only a specific block for fragment responses:

```rust
#[derive(Template)]
#[template(path = "items.html", block = "item_row")]
struct ItemRowFragment {
    item: Item,
}

async fn add_item(Form(input): Form<NewItem>) -> Html<String> {
    let item = create_item(input).await;
    let fragment = ItemRowFragment { item };
    Html(fragment.render().unwrap())
}
```

### Using askama_axum

With `askama_axum`, templates implement `IntoResponse` automatically:

```toml
[dependencies]
askama = "0.15"
askama_axum = "0.5"
```

```rust
use askama_axum::Template;

#[derive(Template)]
#[template(path = "page.html")]
struct PageTemplate {
    title: String,
}

async fn get_page() -> PageTemplate {
    PageTemplate { title: "Hello".into() }
}
```

### HX-Trigger Response Header

Trigger client-side events from server:

```rust
use axum::response::{IntoResponse, Response};
use axum::http::header;

async fn create_item(Form(input): Form<NewItem>) -> Response {
    let item = save_item(input).await;
    let html = ItemTemplate { item }.render().unwrap();

    (
        [(header::HeaderName::from_static("hx-trigger"),
          r#"{"itemCreated": "Item saved successfully"}"#)],
        Html(html)
    ).into_response()
}
```

Client listens:
```html
<div @item-created.window="showToast($event.detail)">
```

### Detecting HTMX Requests

Return different content for HTMX vs full page requests:

```rust
use axum::http::HeaderMap;

async fn get_items(headers: HeaderMap) -> impl IntoResponse {
    let items = fetch_items().await;

    if headers.contains_key("hx-request") {
        // Return fragment only
        Html(ItemListFragment { items }.render().unwrap())
    } else {
        // Return full page
        Html(ItemsPage { items }.render().unwrap())
    }
}
```

### Form Validation

Return validation errors as HTML:

```rust
async fn create_user(Form(input): Form<NewUser>) -> impl IntoResponse {
    match validate_user(&input) {
        Ok(user) => {
            let created = save_user(user).await;
            (
                StatusCode::CREATED,
                Html(UserRowTemplate { user: created }.render().unwrap())
            )
        }
        Err(errors) => {
            (
                StatusCode::UNPROCESSABLE_ENTITY,
                Html(ValidationErrorsTemplate { errors }.render().unwrap())
            )
        }
    }
}
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Returning JSON | HTMX expects HTML | Return Html<String> |
| Missing Content-Type | Browser treats as plain text | askama_axum sets it automatically |
| Panic on render error | Handler crashes | Use `?` or handle Result |
| Returning full page for fragment | Content duplicated | Use block-specific template |

## Resources

- [Axum Documentation](https://docs.rs/axum/latest/axum/)
- [askama_axum Crate](https://docs.rs/askama_axum)
- [HX-Trigger Header](https://htmx.org/headers/hx-trigger/)
- **See also:** askama plugin for template patterns
