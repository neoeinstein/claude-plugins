# HTMX + Alpine.js Plugin - Design Notes

## Current State (v0.1.0)

Stub skill seeded from HTMX+Alpine patterns used in the constant-gathering project. Currently covers the basic interaction model and when-to-use guidance.

## Future Design Scope

### htmx.org Research
- Research htmx.org documentation for patterns not yet covered
- Extensions ecosystem (sse, ws, response-targets, etc.)
- `hx-boost` for progressive enhancement of traditional links/forms

### Deeper HTMX Coverage
- SSE and WebSocket extensions for real-time updates
- Error handling patterns (response codes, `hx-on::response-error`)
- `hx-push-url` for browser history management
- Out-of-band swaps (`hx-swap-oob`) for updating multiple page sections
- HTMX request/response headers for server-side logic

### Deeper Alpine Coverage
- `$store` for global state management
- `x-transition` for animations
- `Alpine.data()` for reusable component patterns
- `$refs` for DOM element access when needed
- Teleport (`x-teleport`) for modals and overlays

### Integration Patterns
- Template partial rendering strategies (per-framework)
- CSRF token handling with HTMX
- Authentication and session management
- Progressive enhancement from plain HTML
- Testing HTMX interactions (e.g., with Playwright)

### Language-Specific Variants
- Currently language-agnostic; may need framework-specific guidance for:
  - axum + Askama (Rust)
  - Django templates (Python)
  - Go templates
