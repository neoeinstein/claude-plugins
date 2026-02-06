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

Server sends HTML:
```html
<div id="messages" hx-swap-oob="beforeend">
    <p>User: Hello</p>
</div>
```

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

## Resources

- [HTMX SSE Extension](https://htmx.org/extensions/sse/)
- [HTMX WebSocket Extension](https://htmx.org/extensions/ws/)
- [MDN: Server-Sent Events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [MDN: WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)
