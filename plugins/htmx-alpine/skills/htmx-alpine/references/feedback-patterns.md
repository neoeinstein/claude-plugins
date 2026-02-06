# Loading and Feedback Patterns

## When to Use This Reference

- Adding loading spinners or indicators
- Disabling elements during requests
- Handling errors gracefully
- Providing optimistic UI feedback

## Quick Reference

| Pattern | HTMX Approach | Alpine Approach |
|---------|---------------|-----------------|
| Loading spinner | `hx-indicator` | `x-show` with event |
| Disable button | `hx-disabled-elt` | `:disabled` with state |
| Error message | Response content | `@htmx:response-error` |
| Progress text | Swap content | `x-text` with state |

## The Rule

Users need feedback during network requests. Something visible should change within 100ms of user action. HTMX provides built-in indicators; Alpine provides flexible state-based UI.

## Patterns

### HTMX Indicator

```html
<style>
    .htmx-indicator { display: none; }
    .htmx-request .htmx-indicator { display: inline; }
    .htmx-request.htmx-indicator { display: inline; }
</style>

<button hx-post="/action" hx-indicator="#spinner">
    Submit
    <span id="spinner" class="htmx-indicator">Loading...</span>
</button>
```

The `.htmx-request` class is added during requests.

### Disable During Request

```html
<button hx-post="/action"
        hx-disabled-elt="this"
        hx-indicator=".spinner">
    <span class="spinner htmx-indicator">⏳</span>
    Submit
</button>
```

`hx-disabled-elt="this"` disables the triggering element during request.

### Alpine-Based Loading State

More control with Alpine events:

```html
<div x-data="{ loading: false }">
    <button hx-post="/action"
            @htmx:before-request="loading = true"
            @htmx:after-request="loading = false"
            :disabled="loading"
            :class="{ 'opacity-50': loading }">
        <span x-show="!loading">Submit</span>
        <span x-show="loading">Processing...</span>
    </button>
</div>
```

### Error Handling

```html
<div x-data="{ error: '' }">
    <form hx-post="/action"
          hx-target="#result"
          @htmx:response-error="error = 'Something went wrong'"
          @htmx:before-request="error = ''">
        <button type="submit">Submit</button>
    </form>

    <div x-show="error" x-text="error" class="error-message"></div>
    <div id="result"></div>
</div>
```

### Server-Side Error Response

Return error HTML directly:

```html
<!-- Server returns this for validation errors -->
<div class="error">
    <ul>
        <li>Email is required</li>
        <li>Password must be 8+ characters</li>
    </ul>
</div>
```

Target a specific error container or use `hx-swap="innerHTML"` on the form.

### Inline Validation

```html
<input type="email" name="email"
       hx-get="/validate/email"
       hx-trigger="blur changed delay:500ms"
       hx-target="next .validation-message">
<span class="validation-message"></span>
```

Server returns empty string for valid, error message for invalid.

### Skeleton Loading

```html
<div hx-get="/content" hx-trigger="load" hx-swap="outerHTML">
    <div class="skeleton">
        <div class="skeleton-line"></div>
        <div class="skeleton-line"></div>
    </div>
</div>
```

The skeleton is replaced when content loads.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| No loading indicator | Users click multiple times | Add hx-indicator or Alpine state |
| No disabled state | Duplicate submissions | Add hx-disabled-elt or :disabled |
| Silent errors | Users don't know it failed | Add @htmx:response-error handler |
| Indicator wrong element | Indicator doesn't show | Check CSS selector, element visibility |

## CSS for Indicators

```css
/* Basic indicator */
.htmx-indicator {
    display: none;
}
.htmx-request .htmx-indicator,
.htmx-request.htmx-indicator {
    display: inline-block;
}

/* Disable pointer events during request */
.htmx-request {
    pointer-events: none;
    opacity: 0.7;
}

/* Skeleton animation */
.skeleton {
    background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
    background-size: 200% 100%;
    animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
}
```

## Resources

- [hx-indicator Reference](https://htmx.org/attributes/hx-indicator/)
- [hx-disabled-elt Reference](https://htmx.org/attributes/hx-disabled-elt/)
- [HTMX CSS Classes](https://htmx.org/docs/#css-classes)
