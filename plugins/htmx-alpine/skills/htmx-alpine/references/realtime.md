# Real-time with SSE and WebSockets

## When to Use This Reference

- Adding live updates (notifications, feeds, dashboards)
- Choosing between SSE and WebSocket
- Implementing HTMX SSE or WebSocket extensions
- Handling reconnection and error states

## Quick Reference

| Need | Use | Extension |
|------|-----|-----------|
| Server-to-client only | SSE | `sse` |
| Bidirectional | WebSocket | `ws` |
| Infrequent updates | SSE or polling | `sse` or `hx-trigger="every Xs"` |
| High-frequency, low-latency | WebSocket | `ws` |

## The Rule

**SSE (Server-Sent Events)**: Lightweight, uni-directional (server → client). Works through proxies. Auto-reconnects. Best for notifications, live feeds, dashboards.

**WebSocket**: Bidirectional. Lower latency. Better for chat, collaborative editing, gaming. Requires explicit reconnection logic.

## Patterns

### SSE Extension Setup

Include the extension:
```html
<script src="https://unpkg.com/htmx-ext-sse@2.2.2/sse.js"></script>
```

Connect to SSE endpoint:
```html
<div hx-ext="sse" sse-connect="/events">
    <div sse-swap="notification">
        <!-- Swapped when server sends event named "notification" -->
    </div>
    <div sse-swap="message">
        <!-- Swapped when server sends event named "message" -->
    </div>
</div>
```

Server sends:
```
event: notification
data: <div class="notification">New notification!</div>

event: message
data: <div class="message">Hello from server</div>
```

### SSE Swap Strategies

```html
<!-- Replace content (default) -->
<div sse-swap="update">Old content</div>

<!-- Append new content -->
<div sse-swap="update" hx-swap="beforeend">
    <!-- New items added here -->
</div>
```

### WebSocket Extension Setup

Include the extension:
```html
<script src="https://unpkg.com/htmx-ext-ws@2.0.1/ws.js"></script>
```

Connect to WebSocket:
```html
<div hx-ext="ws" ws-connect="/ws">
    <div id="messages">
        <!-- Messages swapped here -->
    </div>

    <form ws-send>
        <input name="message">
        <button type="submit">Send</button>
    </form>
</div>
```

Form submission sends JSON to server. Server sends HTML back.

### WebSocket Message Format

Client sends (from form):
```json
{"message": "Hello", "HEADERS": {...}}
```

Server **always** sends HTML fragments — never JSON:
```html
<div id="messages" hx-swap-oob="beforeend">
    <p>User: Hello</p>
</div>
```

### WebSocket Responses Must Be HTML Fragments

This is the most common mistake with htmx-ws: sending JSON and post-processing it client-side. **Don't.** The server renders HTML. The server sends HTML. HTMX swaps it. No client-side template logic.

| Approach | Correct? | Why |
|----------|----------|-----|
| Server sends `<div id="status" hx-swap-oob="innerHTML">Online</div>` | Yes | Server renders, HTMX swaps |
| Server sends `{"status": "online"}` + client builds DOM | **No** | Duplicates rendering on client, breaks source-of-truth |
| Server sends `{"type": "refresh", "section": "status"}` + client fetches | **No** | Extra round-trip, JSON signal is unnecessary indirection |

If you find yourself writing JavaScript that receives JSON from a WebSocket and constructs HTML, you've left the HTMX model. Refactor: have the server render the fragment and send it directly.

### Multi-Fragment WebSocket Messages

htmx-ws swaps every incoming element by `id` (implicit `hx-swap-oob="true"`). A single WebSocket message can contain multiple top-level elements — each is found and swapped independently:

```html
<!-- Server sends this as one WebSocket message -->
<div id="participant-list" hx-swap-oob="innerHTML">
    <ul><li>Alice</li><li>Bob</li></ul>
</div>
<div id="participant-count" hx-swap-oob="innerHTML">
    <span>2 participants</span>
</div>
<div id="status-badge" hx-swap-oob="innerHTML">
    <span class="badge badge-active">Active</span>
</div>
```

### `<template>` Wrappers for Spec-Invalid Standalone Elements

Some HTML elements can't exist as top-level roots without a parent context — `<tr>`, `<td>`, `<li>`, `<option>`, and SVG elements. The browser's HTML parser will mangle or discard them. Wrap these in `<template>` to preserve their structure:

```html
<!-- Each <template> provides its own parsing context -->
<template>
    <tr id="row-42" hx-swap-oob="outerHTML">
        <td>Alice</td><td>Confirmed</td>
    </tr>
</template>
<template>
    <li id="attendee-alice" hx-swap-oob="outerHTML">
        Alice (confirmed)
    </li>
</template>
<!-- Elements that CAN standalone don't need wrapping -->
<div id="participant-count" hx-swap-oob="innerHTML">
    <span>2 participants</span>
</div>
```

**Use one `<template>` per fragment, not one `<template>` around everything.** Mixing elements with incompatible parsing contexts (e.g., a `<tr>` and a `<div>`) inside a single `<template>` causes the same parser-mangling you're trying to avoid. Each `<template>` establishes its own inert parsing context for its children.

### OOB Section Refresh Pattern

Instead of sending granular JSON signals that tell the client *what changed*, send re-rendered HTML sections that show the *current state*. Each section is a self-contained OOB swap:

```html
<!-- Re-rendered section: the server re-renders the whole section -->
<div id="registration-summary" hx-swap-oob="innerHTML">
    <dl>
        <dt>Registered</dt><dd>14</dd>
        <dt>Waitlisted</dt><dd>3</dd>
    </dl>
</div>
<!-- Another section, independently swapped -->
<div id="attendee-table-wrapper" hx-swap-oob="innerHTML">
    <table>
        <tr><td>Alice</td><td>Confirmed</td></tr>
        <tr><td>Bob</td><td>Waitlisted</td></tr>
    </table>
</div>
```

This pattern naturally replaces JSON signal approaches like `{"action": "increment_count", "section": "registration"}`. The server already knows the current state — just render it.

### Idempotent WebSocket Updates

WebSocket messages may arrive out of order or be replayed on reconnection. Use element-level versioning to prevent stale updates from overwriting newer state:

```html
<!-- Server includes a version or timestamp on each fragment -->
<div id="section-a" hx-swap-oob="innerHTML" data-version="42">
    Current content at version 42
</div>
```

```html
<!-- Client-side guard: skip swaps where the existing version is newer -->
<div hx-ext="ws" ws-connect="/ws"
     @htmx:oob-before-swap.window="
         let existing = $event.detail.target;
         let incoming = $event.detail.fragment;
         if (existing?.dataset.version && incoming?.dataset?.version &&
             Number(existing.dataset.version) >= Number(incoming.dataset.version)) {
             $event.detail.shouldSwap = false;
         }
     ">
</div>
```

When to use idempotent versioning:
- **Always** for sections that update independently at different rates
- **Always** when reconnection replays recent messages
- **Optional** for append-only feeds (use message IDs to skip duplicates instead)

### Polling Alternative

For simpler cases, polling may suffice:

```html
<div hx-get="/updates"
     hx-trigger="every 5s"
     hx-swap="innerHTML">
    <!-- Content refreshed every 5 seconds -->
</div>
```

Add `[hx-trigger*='every'] { ... }` CSS for visual indicator.

### Reconnection Handling

SSE auto-reconnects. For WebSocket:

```html
<div hx-ext="ws"
     ws-connect="/ws"
     @htmx:wsClose="setTimeout(() => $el.setAttribute('ws-connect', '/ws'), 5000)">
    <!-- Reconnects after 5 seconds on close -->
</div>
```

## When to Use Each

| Scenario | Recommendation |
|----------|----------------|
| Live notifications | SSE |
| Dashboard metrics | SSE |
| Chat application | WebSocket |
| Collaborative editing | WebSocket |
| Activity feed | SSE |
| Game state | WebSocket |
| Stock prices | SSE (read-only) or WebSocket (if trading) |

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Missing extension script | Nothing happens | Include ext script before use |
| Wrong event name | Content not swapped | Match sse-swap to server event name |
| No reconnection logic (WS) | Stays disconnected | Add htmx:wsClose handler |
| Using WS for one-way | Unnecessary complexity | Use SSE for server-to-client only |
| Sending JSON over WS | Client needs JS to build DOM | Server must send HTML fragments |
| One `<template>` around everything | Parser mangles mixed elements | One `<template>` per fragment |
| Bare `<tr>`/`<li>` as top-level | Element silently discarded | Wrap in `<template>` |

## Resources

- [HTMX SSE Extension](https://htmx.org/extensions/sse/)
- [HTMX WebSocket Extension](https://htmx.org/extensions/ws/)
- [hx-swap-oob Reference](https://htmx.org/attributes/hx-swap-oob/) — OOB swap mechanics, `<template>` wrapping rules
- [MDN: Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [MDN: WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
