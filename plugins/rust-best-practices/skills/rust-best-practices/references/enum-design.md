# Enum Design in Rust

## Quick Reference

| Situation | Approach |
|-----------|----------|
| Function with a `bool` parameter | Replace with a descriptive enum |
| Public API enum genuinely expected to grow | `#[non_exhaustive]` (see caveat) |
| Internal enum, or one unlikely to grow | No `#[non_exhaustive]` |

## Replace Boolean Parameters with Enums

`bool` parameters are "boolean blindness" — at the call site you can't tell what `true` or `false` means without opening the signature.

```rust
// ❌ BAD - boolean blindness
fn send_email(to: &str, is_urgent: bool, include_attachment: bool) { }
send_email("user@example.com", true, false);  // what do these mean?

// ✅ GOOD - self-documenting
enum Priority { Normal, Urgent }
enum Attachment { None, Include(PathBuf) }

fn send_email(to: &str, priority: Priority, attachment: Attachment) { }
send_email("user@example.com", Priority::Urgent, Attachment::None);
```

The payoff is at the **call site**: `Priority::Urgent` reads correctly on its own; `true` forces the reader to go find the parameter it binds to.

## When Boolean is OK

- Single, unambiguous meaning: `is_empty()`, `contains()`
- Return values, not parameters
- Internal implementation where the meaning is obvious

## `#[non_exhaustive]` Is Double-Edged

`#[non_exhaustive]` lets you add enum variants later without a breaking change — but it has real costs, so reach for it only where variants are **genuinely expected to grow**:

- Downstream crates lose exhaustiveness checking: they're forced to add a `_ =>` arm, which then silently absorbs every variant you add later — the opposite of the compile-time coverage enums exist for.
- It's **inert within the defining crate** — your own code still gets full exhaustiveness checking, so it buys nothing internally.

```rust
#[non_exhaustive]
pub enum ErrorKind { NotFound, PermissionDenied, Timeout }

// Downstream consumers are forced into a wildcard arm:
match error.kind() {
    ErrorKind::NotFound => { /* ... */ }
    ErrorKind::PermissionDenied => { /* ... */ }
    ErrorKind::Timeout => { /* ... */ }
    _ => { /* forced; silently absorbs future variants */ }
}
```

## Resources

- Replacing Boolean Flags with Enum Variants: https://www.slingacademy.com/article/replacing-boolean-flags-with-meaningful-enum-variants/
- Rust API Guidelines: https://rust-lang.github.io/api-guidelines/
