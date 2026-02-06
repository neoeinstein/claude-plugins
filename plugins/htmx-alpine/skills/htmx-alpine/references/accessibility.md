# Accessibility for Dynamic UIs

## When to Use This Reference

- Adding dynamic content that screen readers need to announce
- Managing focus after HTMX swaps
- Building accessible modals, dropdowns, accordions
- Concerned about keyboard navigation

## Quick Reference

| Need | Solution |
|------|----------|
| Announce dynamic content | `aria-live="polite"` on container |
| Indicate loading | `aria-busy="true"` during request |
| Mark invalid field | `aria-invalid="true"` + `aria-describedby` |
| Modal focus | Trap focus, return on close |
| Keyboard nav | Proper roles, tabindex, key handlers |

## The Rule

Dynamic content changes must be perceivable by all users:
- **Announce changes** via ARIA live regions
- **Manage focus** when content swaps
- **Support keyboard** for all interactions
- **Maintain semantics** with proper ARIA roles

## STOP and Reconsider

**Before skipping accessibility, STOP.**

| Situation | Why you're wrong | What to do |
|-----------|------------------|------------|
| "PM says ship it, audit is later" | Users with disabilities can't use it NOW | Add basic accessibility with HTMX; takes 10 minutes |
| "Modal works visually" | Keyboard/screen reader users are trapped or lost | Add focus trap, Escape to close |
| "It's just internal tooling" | Employees have disabilities too | Same accessibility standards apply |
| "No one complained" | Users leave, they don't complain | Test with screen reader |
| "We'll fix it in the redesign" | You won't, and users suffer until then | Fix it now |

**Accessibility is not optional. It's a legal requirement in many jurisdictions and an ethical imperative everywhere.**

## Patterns

### ARIA Live Regions

Announce content changes to screen readers:

```html
<div aria-live="polite" aria-atomic="true" id="notifications">
    <!-- HTMX swaps new content here, announced automatically -->
</div>

<button hx-post="/action" hx-target="#notifications">
    Do Action
</button>
```

- `aria-live="polite"`: Announce when screen reader is idle
- `aria-live="assertive"`: Interrupt immediately (use sparingly)
- `aria-atomic="true"`: Announce entire region, not just changes

### Loading State Announcement

```html
<div x-data="{ loading: false }"
     :aria-busy="loading"
     aria-live="polite">
    <button hx-get="/data"
            hx-target="#results"
            @htmx:before-request="loading = true"
            @htmx:after-request="loading = false">
        Load Data
    </button>
    <div id="results">
        <span x-show="loading">Loading...</span>
    </div>
</div>
```

### Focus After Swap

Move focus to new content:

```html
<button hx-get="/form"
        hx-target="#modal-content"
        hx-on::after-swap="document.querySelector('#modal-content input')?.focus()">
    Open Form
</button>
```

### Accessible Modal

```html
<div x-data="{ open: false }"
     @keydown.escape.window="open && (open = false)">
    <button @click="open = true">Open Modal</button>

    <div x-show="open"
         x-trap.inert="open"
         role="dialog"
         aria-modal="true"
         aria-labelledby="modal-title"
         x-cloak>
        <h2 id="modal-title">Modal Title</h2>
        <div>Modal content...</div>
        <button @click="open = false">Close</button>
    </div>
</div>
```

Requires Alpine Focus plugin for `x-trap`:
```html
<script defer src="https://cdn.jsdelivr.net/npm/@alpinejs/focus@3.x.x/dist/cdn.min.js"></script>
```

### Form Validation Errors

```html
<div>
    <label for="email">Email</label>
    <input type="email"
           id="email"
           name="email"
           hx-get="/validate/email"
           hx-trigger="blur changed"
           hx-target="next .error"
           aria-describedby="email-error">
    <span id="email-error" class="error" role="alert"></span>
</div>
```

Server returns:
```html
<!-- Valid -->
<span id="email-error" class="error" role="alert"></span>

<!-- Invalid -->
<span id="email-error" class="error" role="alert">
    Please enter a valid email address
</span>
```

### Accessible Dropdown

```html
<div x-data="{ open: false }">
    <button @click="open = !open"
            aria-haspopup="true"
            :aria-expanded="open">
        Menu
    </button>
    <ul x-show="open"
        role="menu"
        x-cloak
        @keydown.escape="open = false"
        @keydown.arrow-down.prevent="$focus.wrap().next()"
        @keydown.arrow-up.prevent="$focus.wrap().previous()">
        <li role="menuitem"><a href="/profile">Profile</a></li>
        <li role="menuitem"><a href="/settings">Settings</a></li>
    </ul>
</div>
```

## Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| No live region | Screen reader users miss updates | Add aria-live to swap targets |
| Focus not managed | Users lost after swap | Move focus to new content |
| No keyboard support | Keyboard users can't navigate | Add tabindex, key handlers |
| Missing ARIA roles | Semantics unclear | Add appropriate roles |
| Modal without focus trap | Users tab outside modal | Use x-trap or equivalent |

## Testing Checklist

- [ ] Tab through entire page — all interactive elements reachable
- [ ] Escape closes modals/dropdowns
- [ ] Focus visible on all interactive elements
- [ ] Screen reader announces dynamic updates
- [ ] Forms announce errors
- [ ] Content works without JavaScript (progressive enhancement)

## Resources

- [MDN: ARIA Live Regions](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions)
- [Alpine Focus Plugin](https://alpinejs.dev/plugins/focus)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [A11y Project Checklist](https://www.a11yproject.com/checklist/)
