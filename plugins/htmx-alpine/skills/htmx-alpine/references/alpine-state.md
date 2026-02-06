# Alpine.js State Management

## When to Use This Reference

- Managing UI state with x-data and x-model
- Deciding what state belongs in Alpine vs on the server
- State is getting complex and you're unsure if Alpine is the right tool
- Using x-show, x-if, and other reactive directives

## Quick Reference

| Directive | Purpose | Example |
|-----------|---------|---------|
| `x-data` | Declare component state | `x-data="{ open: false }"` |
| `x-model` | Two-way binding | `x-model="email"` |
| `x-show` | Toggle visibility (CSS) | `x-show="open"` |
| `x-if` | Conditional render (DOM) | `x-if="showAdvanced"` |
| `x-text` | Set text content | `x-text="message"` |
| `x-html` | Set HTML content | `x-html="content"` (caution) |
| `:class` | Reactive classes | `:class="{ active: isActive }"` |
| `@click` | Event handler | `@click="open = !open"` |

## The Rule

Alpine.js manages **UI-only state** — state that doesn't need to persist if the user refreshes. Examples: dropdown visibility, modal open/closed, form field focus, tab selection.

**Server state stays on the server.** If you need the data after a refresh, it belongs on the server, not in `x-data`.

## STOP and Reconsider

**Before adding more state to Alpine, STOP.**

| Situation | Why Alpine is wrong | What to do |
|-----------|---------------------|------------|
| "User filled out 3 wizard steps" | Refresh loses everything | Submit each step to server with HTMX |
| "Caching server response in x-data" | Stale data, sync issues | Let HTMX fetch fresh data |
| "Shopping cart in Alpine" | Lost on refresh, can't share | Store in server session, render with HTMX |
| "x-data object is 50+ lines" | Alpine isn't a framework | Reconsider architecture; maybe use Vue/React |
| "Sharing state between components" | Alpine is component-scoped | Use server state or Alpine `$store` sparingly |

**Signs you've outgrown Alpine:**
- Needing complex computed properties
- State shared across many unrelated components
- State that must persist across page navigation
- Need for client-side routing
- Complex async data fetching

## Patterns

### Simple Toggle

```html
<div x-data="{ open: false }">
    <button @click="open = !open">Menu</button>
    <nav x-show="open" x-cloak>
        <!-- menu items -->
    </nav>
</div>
```

### Form Field Binding

```html
<div x-data="{ email: '', valid: false }">
    <input type="email" x-model="email"
           @input="valid = email.includes('@')">
    <span x-show="!valid && email.length > 0">
        Enter a valid email
    </span>
</div>
```

### x-show vs x-if

Use `x-show` when:
- Element toggles frequently
- Element has expensive initialization
- You need CSS transitions

Use `x-if` when:
- Element rarely shown
- Contains sensitive data (not in DOM when hidden)
- Reduces DOM size significantly

```html
<!-- x-show: hidden with CSS, still in DOM -->
<div x-show="visible">Always in DOM</div>

<!-- x-if: removed from DOM entirely -->
<template x-if="visible">
    <div>Only in DOM when visible</div>
</template>
```

### Prevent Flash of Unstyled Content

Always include this CSS:

```css
[x-cloak] { display: none !important; }
```

And add `x-cloak` to elements that should be hidden until Alpine initializes:

```html
<div x-data="{ open: false }">
    <nav x-show="open" x-cloak>
        <!-- Hidden until Alpine ready -->
    </nav>
</div>
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Server data in x-data | Stale data, refresh loses state | Keep on server, fetch with HTMX |
| Missing x-cloak | Flash of hidden content | Add `[x-cloak]` CSS and attribute |
| Complex nested state | Hard to debug, slow | Flatten state or move to server |
| Using x-html with user content | XSS vulnerability | Use x-text or sanitize server-side |

## When Alpine Isn't Enough

Alpine is intentionally minimal. If you need:

| Need | Solution |
|------|----------|
| Global state | Server-side state + HTMX, or consider Vue/React |
| Client-side routing | HTMX hx-push-url, or SPA framework |
| Complex forms | Multi-step forms via HTMX |
| Real-time data | HTMX SSE/WS extension |

## Resources

- [Alpine.js Documentation](https://alpinejs.dev/)
- [x-data Reference](https://alpinejs.dev/directives/data)
- [x-model Reference](https://alpinejs.dev/directives/model)
