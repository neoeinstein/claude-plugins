# HTMX + Alpine.js Integration

## When to Use This Reference

- Coordinating HTMX requests with Alpine state
- Using @htmx:* events in Alpine expressions
- Building complex workflows that need both
- Handling HTMX lifecycle events

## Quick Reference

| Event | When it fires | Common use |
|-------|---------------|------------|
| `htmx:before-request` | Before request sent | Set loading state |
| `htmx:after-request` | After request completes | Clear loading state |
| `htmx:before-swap` | Before content swapped | Prepare for update |
| `htmx:after-swap` | After content swapped | Re-initialize, focus |
| `htmx:response-error` | On HTTP error | Show error message |
| `htmx:send-error` | On network error | Show offline message |

## The Rule

HTMX and Alpine have different responsibilities:
- **HTMX**: Server communication, DOM updates from server responses
- **Alpine**: Client-side UI state, immediate visual feedback

They integrate through Alpine listening to HTMX events.

## Patterns

### Form with Loading State

```html
<div x-data="{ submitting: false, error: '' }">
    <form hx-post="/api/action"
          hx-target="#result"
          @htmx:before-request="submitting = true; error = ''"
          @htmx:after-request="submitting = false"
          @htmx:response-error="error = 'Request failed. Please try again.'">

        <input type="text" name="query" :disabled="submitting">

        <button type="submit" :disabled="submitting">
            <span x-show="!submitting">Search</span>
            <span x-show="submitting">Searching...</span>
        </button>

        <div x-show="error" x-text="error" class="error"></div>
    </form>
    <div id="result"></div>
</div>
```

### Handling Server-Triggered Events

Server can trigger custom events via `HX-Trigger` response header:

```python
# Server response header
HX-Trigger: {"showToast": "Item saved successfully"}
```

```html
<div x-data="{ toast: '', show: false }"
     @show-toast.window="toast = $event.detail.value; show = true; setTimeout(() => show = false, 3000)">
    <div x-show="show" x-text="toast" class="toast"></div>
</div>
```

### After-Swap Reinitialization

When HTMX swaps content, new Alpine components need initialization:

```html
<div @htmx:after-swap.window="$nextTick(() => { /* reinit logic */ })">
    <!-- HTMX target inside -->
</div>
```

Note: Alpine auto-initializes new `x-data` elements in swapped content as of Alpine 3.x.

### Delete with Confirmation

```html
<div x-data="{ confirming: false }">
    <button x-show="!confirming" @click="confirming = true">
        Delete
    </button>
    <div x-show="confirming">
        <span>Are you sure?</span>
        <button hx-delete="/item/123"
                hx-target="closest .item"
                hx-swap="outerHTML"
                @htmx:after-request="confirming = false">
            Yes, delete
        </button>
        <button @click="confirming = false">Cancel</button>
    </div>
</div>
```

### Optimistic Updates

Show immediate feedback while waiting for server:

```html
<div x-data="{ liked: false, count: 42 }">
    <button hx-post="/like"
            hx-swap="none"
            @click="liked = !liked; count += liked ? 1 : -1"
            @htmx:response-error="liked = !liked; count += liked ? 1 : -1">
        <span x-text="liked ? '❤️' : '🤍'"></span>
        <span x-text="count"></span>
    </button>
</div>
```

Rollback on error by reversing the optimistic update.

## Event Scoping

HTMX events bubble. To listen only on specific elements:

```html
<!-- Listen on this element only -->
<form @htmx:after-request="handleComplete">

<!-- Listen on window (any HTMX request) -->
<div @htmx:after-request.window="handleAnyComplete">
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Listening for wrong event | Handler never fires | Check event name (htmx:after-swap vs htmx:afterSwap) |
| Not using .window modifier | Missing events from children | Add .window or listen on correct ancestor |
| Forgetting error handling | Silent failures | Add @htmx:response-error handler |
| Alpine state vs HTMX response | State out of sync | Let server be source of truth |

## Resources

- [HTMX Events Reference](https://htmx.org/events/)
- [HX-Trigger Response Header](https://htmx.org/headers/hx-trigger/)
- [Alpine Event Handling](https://alpinejs.dev/directives/on)
