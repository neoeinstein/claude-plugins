# HTMX Requests

## When to Use This Reference

- Making server requests with hx-get, hx-post, hx-put, hx-delete
- Controlling where responses render with hx-target and hx-swap
- Customizing when requests trigger with hx-trigger
- Understanding swap strategies for different update patterns

## Quick Reference

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `hx-get` | GET request | `hx-get="/items"` |
| `hx-post` | POST request | `hx-post="/items"` |
| `hx-put` | PUT request | `hx-put="/items/1"` |
| `hx-delete` | DELETE request | `hx-delete="/items/1"` |
| `hx-target` | Where to put response | `hx-target="#result"` |
| `hx-swap` | How to insert response | `hx-swap="innerHTML"` |
| `hx-trigger` | When to send request | `hx-trigger="click"` |

## The Rule

HTMX extends HTML with attributes for making AJAX requests. The server returns HTML fragments, which HTMX swaps into the DOM. No JavaScript required.

## Patterns

### Basic Request

```html
<button hx-post="/api/action" hx-target="#result">
    Do Action
</button>
<div id="result"></div>
```

The server response HTML replaces the content of `#result`.

### Form Submission

```html
<form hx-post="/users" hx-target="#user-list" hx-swap="beforeend">
    <input name="name" required>
    <button type="submit">Add User</button>
</form>
<ul id="user-list"></ul>
```

Server returns `<li>New User</li>`, appended to the list.

### Swap Strategies

| Strategy | Behavior |
|----------|----------|
| `innerHTML` | Replace inner content (default) |
| `outerHTML` | Replace entire target element |
| `beforeend` | Append to end of target |
| `afterbegin` | Prepend to start of target |
| `beforebegin` | Insert before target element |
| `afterend` | Insert after target element |
| `delete` | Remove the target element |
| `none` | Don't swap (process OOB only) |

### Trigger Customization

```html
<!-- Trigger on blur with delay -->
<input hx-get="/validate" hx-trigger="blur changed delay:500ms">

<!-- Trigger once on load -->
<div hx-get="/lazy-content" hx-trigger="load once"></div>

<!-- Trigger when scrolled into view -->
<div hx-get="/more-items" hx-trigger="revealed"></div>
```

### Targeting Different Elements

```html
<!-- Target by ID -->
<button hx-get="/content" hx-target="#panel">Load</button>

<!-- Target closest ancestor -->
<button hx-get="/row" hx-target="closest tr">Update Row</button>

<!-- Target with CSS selector -->
<button hx-get="/header" hx-target="body > header">Refresh Header</button>
```

### Out-of-Band Swaps

Server can update multiple elements in one response:

```html
<!-- In server response -->
<div id="main-content">Main update</div>
<div id="sidebar" hx-swap-oob="true">Sidebar update</div>
<div id="notification" hx-swap-oob="innerHTML">New notification</div>
```

Elements with `hx-swap-oob` are swapped by ID regardless of target.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Missing `hx-target` | Content replaces trigger element | Add `hx-target` selector |
| Wrong swap strategy | Content in wrong position | Use correct `hx-swap` value |
| Triggering too often | Server overload | Add `delay` or `throttle` to trigger |
| Returning full page | Page duplicated in target | Return fragment only |

## Resources

- [hx-get Reference](https://htmx.org/attributes/hx-get/)
- [hx-target Reference](https://htmx.org/attributes/hx-target/)
- [hx-swap Reference](https://htmx.org/attributes/hx-swap/)
- [hx-trigger Reference](https://htmx.org/attributes/hx-trigger/)
