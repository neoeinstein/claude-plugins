# Enum Design in Rust

## When to Use This Reference

- Seeing `bool` parameters in function signatures
- Designing types with mutually exclusive states
- Deciding between `bool` flags and enums
- Working with public API enums

## Quick Reference

| Situation | Approach |
|-----------|----------|
| Two mutually exclusive options | Enum with two variants |
| Function with `bool` parameter | Replace with descriptive enum |
| Public API enum that may grow | Add `#[non_exhaustive]` |
| Internal enum | No `#[non_exhaustive]` needed |

## The Rule

**Replace boolean parameters with enums.** `bool` parameters are "boolean blindness" - at the call site, you can't tell what `true` or `false` means without checking the signature.

```rust
// ❌ What does `true` mean here?
process_order(order, true);

// ✅ Self-documenting
process_order(order, ShippingPriority::Express);
```

## Patterns

### Replacing Boolean Parameters

```rust
// ❌ BAD - boolean blindness
fn send_email(to: &str, is_urgent: bool, include_attachment: bool) { }

send_email("user@example.com", true, false); // What do these mean?

// ✅ GOOD - self-documenting
enum Priority { Normal, Urgent }
enum Attachment { None, Include(PathBuf) }

fn send_email(to: &str, priority: Priority, attachment: Attachment) { }

send_email("user@example.com", Priority::Urgent, Attachment::None);
```

### Exhaustive Matching

```rust
enum Status {
    Pending,
    Processing,
    Complete,
    Failed,
}

fn handle_status(status: Status) {
    match status {
        Status::Pending => { /* ... */ }
        Status::Processing => { /* ... */ }
        Status::Complete => { /* ... */ }
        Status::Failed => { /* ... */ }
        // Compiler ensures all variants handled
    }
}
```

### Public API Enums with #[non_exhaustive]

```rust
// In your library
#[non_exhaustive]
pub enum ErrorKind {
    NotFound,
    PermissionDenied,
    Timeout,
}

// Consumers must include a wildcard arm
match error.kind() {
    ErrorKind::NotFound => { /* ... */ }
    ErrorKind::PermissionDenied => { /* ... */ }
    ErrorKind::Timeout => { /* ... */ }
    _ => { /* handle future variants */ }
}
```

### Enums with Data

```rust
enum Message {
    Quit,
    Move { x: i32, y: i32 },
    Write(String),
    ChangeColor(u8, u8, u8),
}

fn process(msg: Message) {
    match msg {
        Message::Quit => println!("Quit"),
        Message::Move { x, y } => println!("Move to ({x}, {y})"),
        Message::Write(text) => println!("Text: {text}"),
        Message::ChangeColor(r, g, b) => println!("Color: #{r:02x}{g:02x}{b:02x}"),
    }
}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `fn foo(flag: bool)` | Use a descriptive enum |
| Multiple bool params | Each should be a separate enum |
| Public enum without `#[non_exhaustive]` | Add it if variants may be added later |
| `_ =>` on internal enums | Match all variants explicitly |

## When Boolean is OK

- Single, unambiguous meaning: `is_empty()`, `contains()`
- Return values, not parameters
- Internal implementation where meaning is obvious

## Resources

- Replacing Boolean Flags with Enum Variants: https://www.slingacademy.com/article/replacing-boolean-flags-with-meaningful-enum-variants/
- Rust Book - Enums: https://doc.rust-lang.org/book/ch06-00-enums.html
- Rust API Guidelines: https://rust-lang.github.io/api-guidelines/
