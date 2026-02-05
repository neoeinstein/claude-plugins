# Askama Plugin - Design Notes

## Current State (v0.1.0)

Two skills migrated verbatim from `~/.claude/skills/`:
- **askama-rust-templates**: Writing idiomatic Askama templates using Rust types, methods, and Display implementations
- **askama-debugging**: Debugging template compilation errors through module scope analysis

## Future Improvements

### Structural Review
- Apply anti-rationalization tables (e.g., "about to convert a type to String just to pass to template" -> "fix the module scope instead")
- Add STOP patterns for common mistakes (reverting to Jinja2 idioms, losing type safety)

### Expanded Content
- More complex template inheritance patterns (multiple levels, conditional blocks)
- Working with Askama alongside HTMX (partial template rendering for `hx-swap`)
- Custom filter best practices (when to use filters vs methods vs Display)
- Integration with axum/actix-web response types
- Error handling in templates (displaying user-friendly errors)

### Reference Docs
- Consider splitting into reference docs similar to rust-best-practices if content grows
- Template performance considerations (compiled templates vs runtime overhead)
