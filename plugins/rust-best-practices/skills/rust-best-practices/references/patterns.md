# Design Patterns in Rust

## When to Use This Reference

- Structuring code for maintainability
- Preventing invalid states
- Applying well-known patterns in Rust idiomatically

## Quick Reference

| Pattern | Use When | Canonical home |
|---------|----------|----------------|
| Make Illegal States Unrepresentable | Data has invariants that must always hold | this file |
| Newtype | Need type distinction or validation | `type-safety.md` |
| Enums for exclusive states | Conflicting `bool`s | `enum-design.md` |
| Typestate / Builder | Ordered operations / complex construction | `api-design.md` |

## Make Illegal States Unrepresentable

Design your types so invalid data cannot be constructed. If the compiler accepts it, it should be valid. (This file is the canonical home for the principle.)

```rust
// ❌ BAD - can create invalid states
struct User {
    email: Option<String>,
    email_verified: bool,  // What if email is None but this is true?
}

// ✅ GOOD - invalid states are impossible
enum EmailStatus {
    Unverified(String),
    Verified(String),
}

struct User {
    email: Option<EmailStatus>,
}
```

Collapsing several conflicting `bool` fields into one state enum is a special case of this — see `enum-design.md`.

## Excessive Option/Result Nesting

```rust
// ❌ BAD - deeply nested
fn get_value() -> Option<Result<Option<String>, Error>> { }

// ✅ GOOD - flatten or use a purpose-built type
fn get_value() -> Result<Option<String>, Error> { }
// Or
enum GetValueResult { Found(String), NotFound, Error(Error) }
```

## Stringly-Typed Dispatch

Stringly-typed code is covered in `type-safety.md`. One async-flavored form is worth flagging here: a `publish(kind: &str, bytes: &[u8])` signature is stringly-typed *dispatch* — the caller must supply a matching string and bytes with nothing enforcing agreement. Bind the identity to the payload *type* via a trait instead. See `references/serde.md` § Constructing Output.

## Resources

- Rust Design Patterns Book: https://rust-unofficial.github.io/patterns/
- Make Illegal States Unrepresentable: https://corrode.dev/blog/illegal-state/
- Compile-time Invariants: https://corrode.dev/blog/compile-time-invariants/
