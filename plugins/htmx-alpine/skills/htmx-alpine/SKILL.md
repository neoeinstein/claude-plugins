---
name: htmx-alpine
description: Use when building server-driven web applications with HTMX and Alpine.js - covers the interaction model, when to use each tool, and when NOT to use raw JavaScript
---

# HTMX + Alpine.js Patterns

## Overview

Build server-driven web applications where the server returns HTML and the client manages UI state. HTMX handles all server communication. Alpine.js handles client-side state that doesn't need server round-trips.

**Core principle:** The server is the source of truth. The client is a thin rendering layer.

## Quick Reference

| Need | Use | Not |
|------|-----|-----|
| Submit form to server | HTMX `hx-post` | JavaScript `fetch()` |
| Update page section | HTMX `hx-target` + `hx-swap` | JavaScript DOM manipulation |
| Show/hide element | Alpine `x-show` | JavaScript classList toggle |
| Track form state | Alpine `x-data` + `x-model` | JavaScript variables |
| Loading indicator | HTMX `hx-indicator` or Alpine `:disabled` | JavaScript event handlers |
| Multi-step flow | Alpine state + HTMX requests | JavaScript state machine |

## When to Use Each

### HTMX: Server-Driven Interactions

Use `hx-*` attributes for all server communication:
- Form submissions (`hx-post`, `hx-put`, `hx-delete`)
- Partial page updates (`hx-get` with `hx-target` and `hx-swap`)
- Loading states (`hx-indicator`)
- Inline validation and feedback

### Alpine.js: Client-Side State

Use `x-*` attributes for UI state that doesn't require server round-trips:
- Show/hide toggles (`x-show`, `@click`)
- Form field state (`x-model`, `x-data`)
- Conditional styling (`:class`)
- Client-side validation feedback

**Always add** `[x-cloak] { display: none !important; }` to prevent flash of unstyled content before Alpine initializes.

### Combined HTMX + Alpine

For complex workflows that need both client state and server communication:

```html
<div x-data="{ submitting: false, error: '' }">
    <form hx-post="/api/action"
          hx-target="#result"
          @htmx:before-request="submitting = true; error = ''"
          @htmx:after-request="submitting = false"
          @htmx:response-error="error = 'Request failed'">
        <button type="submit" :disabled="submitting">
            <span x-show="!submitting">Submit</span>
            <span x-show="submitting">Processing...</span>
        </button>
    </form>
    <div x-show="error" x-text="error" class="error"></div>
    <div id="result"></div>
</div>
```

## When NOT to Use JavaScript

Avoid raw JavaScript (`fetch()`, `addEventListener()`, etc.) except for:
- Clipboard operations (`navigator.clipboard`)
- Complex third-party library integration
- Browser APIs not covered by HTMX/Alpine

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `fetch()` for form submissions | Use HTMX `hx-post` |
| JavaScript DOM manipulation for updates | Use HTMX `hx-swap` |
| JavaScript variables for UI state | Use Alpine `x-data` |
| Missing `x-cloak` on Alpine elements | Add `[x-cloak] { display: none !important; }` |
