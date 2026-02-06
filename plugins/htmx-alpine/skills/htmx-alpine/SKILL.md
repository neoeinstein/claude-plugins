---
name: htmx-alpine
description: Use when building server-driven web applications with HTMX and Alpine.js - covers the interaction model, when to use each tool, and when NOT to use raw JavaScript
---

# HTMX + Alpine.js Patterns

## Overview

Build server-driven web applications where the server returns HTML and the client manages UI state. HTMX handles all server communication. Alpine.js handles client-side state that doesn't need server round-trips.

**Core principle:** The server is the source of truth. The client is a thin rendering layer.

## Quick Reference - What to Load

| If you're... | Load |
|--------------|------|
| Using hx-get, hx-post, hx-target, hx-swap | `references/htmx-requests.md` |
| Managing UI state with x-data, x-model | `references/alpine-state.md` |
| Coordinating HTMX and Alpine together | `references/integration.md` |
| Adding loading spinners, error handling | `references/feedback-patterns.md` |
| Using SSE or WebSocket extensions | `references/realtime.md` |
| Concerned about focus, ARIA, screen readers | `references/accessibility.md` |
| Using Axum + Askama for handlers | `references/frameworks/rust-axum.md` |

## When to Use Each

| Need | Use | Not |
|------|-----|-----|
| Submit form to server | HTMX `hx-post` | JavaScript `fetch()` |
| Update page section | HTMX `hx-target` + `hx-swap` | JavaScript DOM manipulation |
| Show/hide element | Alpine `x-show` | JavaScript classList toggle |
| Track form state | Alpine `x-data` + `x-model` | JavaScript variables |
| Loading indicator | HTMX `hx-indicator` or Alpine `:disabled` | JavaScript event handlers |
| Multi-step flow | Alpine state + HTMX requests | JavaScript state machine |
| Real-time updates | HTMX SSE/WS extension | JavaScript WebSocket API |

## Core Principles

**Server is Source of Truth:** Business logic and data validation belong on the server. The client is a rendering layer that displays HTML from the server and provides immediate UI feedback.

**HTMX for Server Roundtrips:** Use `hx-*` attributes for any operation that needs server data: form submissions, partial page updates, search results, inline validation. The server returns HTML fragments, not JSON.

**Alpine for Client-Only State:** Use `x-*` attributes for UI state that never needs to persist: dropdown visibility, modal open/closed, form field focus, character counts. If the user refreshes and the state is gone, that's fine.

**Progressive Enhancement:** The page should be usable without JavaScript. HTMX and Alpine enhance the experience but aren't required for basic functionality.

**Accessibility is Not Optional:** Dynamic content requires focus management, ARIA live regions, and keyboard navigation. See `references/accessibility.md`.

## STOP — Anti-Rationalization Table

Before writing code that matches these patterns, STOP and reconsider.

| You're about to... | Common rationalization | What to do instead |
|--------------------|------------------------|--------------------|
| Use `fetch()` for a form submission | "I know fetch, HTMX is new" / "More control" | Use `hx-post`. HTMX handles all the edge cases you'll forget. Load `references/htmx-requests.md`. |
| Store server data in Alpine `x-data` | "It's faster than round-tripping" / "Just caching" | Keep server data on the server. Alpine state should be UI-only. Load `references/alpine-state.md`. |
| Skip focus management after swap | "Users can click" / "PM says ship it" | Users include keyboard and screen reader users. Load `references/accessibility.md`. |
| Build a wizard with Alpine-only state | "Steps are just UI" | Multi-step flows need server persistence. Use HTMX for each step, Alpine for in-step UI. |
| Ignore loading indicators | "It's fast enough" | It's not always fast. Add `hx-indicator`. Load `references/feedback-patterns.md`. |
| Use `innerHTML` in JavaScript | "Just this once" | Use HTMX `hx-swap`. If you need it, Alpine `x-html` (with caution). |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `fetch()` for form submissions | Use HTMX `hx-post` |
| JavaScript DOM manipulation for updates | Use HTMX `hx-swap` |
| JavaScript variables for UI state | Use Alpine `x-data` |
| Missing `x-cloak` on Alpine elements | Add `[x-cloak] { display: none !important; }` |
| No ARIA live region for dynamic content | Add `aria-live="polite"` to update containers |
| Modal without focus trap | Implement focus trapping or use library |

## Authoritative Resources

- [HTMX Documentation](https://htmx.org/docs/)
- [Alpine.js Documentation](https://alpinejs.dev/)
- [Hypermedia Systems Book](https://hypermedia.systems/)
- [HTMX Essays](https://htmx.org/essays/)
