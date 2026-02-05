# Type Safety in Rust

## When to Use This Reference

- Creating domain types (user IDs, email addresses)
- Seeing `String` or other primitives where semantic types would be clearer
- Wanting validation at construction time
- Reducing "primitive obsession" anti-pattern

## Quick Reference

| Need | Crate | Use Case |
|------|-------|----------|
| Validated newtypes | `nutype` | Types with constraints (non-empty, length limits, ranges) |
| String wrappers | `aliri_braid` | Owned + borrowed pairs (`Name` and `NameRef`) |
| Trait derives | `derive_more` | `From`, `Into`, `Display`, `Deref` on newtypes |
| Decimal values | `rust_decimal` | Precise decimal calculations without float errors |
| Money with currency | `doubloon` | `Money` type with currency handling |
| Simple wrapper | Manual | When you just need type distinction |

## The Rule

**Prefer newtypes over primitives when confusion is possible.** `UserId(String)` is better than `String` because:
- Compiler prevents mixing up `UserId` and `AccountId`
- Validation happens at construction, not scattered throughout code
- Intent is documented in the type system

**When to use newtypes:**
- Identifiers that could be confused (user ID vs product ID vs order ID)
- Validated strings (emails, usernames, URLs)
- Domain concepts with invariants

**When primitives are fine:**
- Obviously numeric values (quantity, count, index)
- Internal implementation details
- Single unambiguous parameter

**Identifiers should be strings** (or KSUIDs/UUIDs), not integers. You don't do math on IDs.

**Money should use `doubloon::Money`** or `rust_decimal::Decimal`, not floats. Floats accumulate rounding errors.

## Patterns

### Simple Newtype (Manual)

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct UserId(String);

impl UserId {
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}
```

### Validated Newtype with nutype

```rust
use nutype::nutype;

#[nutype(
    sanitize(trim, lowercase),
    validate(len_char_min = 1, len_char_max = 100),
    derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)
)]
pub struct Username(String);

// Construction validates automatically
let username = Username::try_new("  Alice  ")?; // Ok("alice")
let invalid = Username::try_new("");            // Err(UsernameError::LenCharMinViolated)
```

### String Wrapper with aliri_braid

```rust
use aliri_braid::braid;

#[braid(serde)]
pub struct DatabaseName;

// Generates both DatabaseName (owned) and DatabaseNameRef (borrowed)
fn connect(name: &DatabaseNameRef) -> Connection { /* ... */ }

let name = DatabaseName::from_static("mydb");
connect(&name);
```

### Deriving Traits with derive_more

```rust
use derive_more::{Display, From, Into};

#[derive(Debug, Clone, Display, From, Into)]
pub struct Email(String);

let email: Email = "user@example.com".to_string().into();
println!("{}", email); // Display works
```

**Note:** Avoid deriving `Deref` on string newtypes - it bypasses type safety through implicit dereferencing. If you need both owned and borrowed forms, use `aliri_braid` instead to get strongly-typed `Email` and `EmailRef`.

### Validated Construction with TryFrom

Use `TryFrom` to validate at construction time. Once a value is constructed, it's always valid:

```rust
use std::num::NonZeroU16;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Port(NonZeroU16);

impl TryFrom<u16> for Port {
    type Error = PortError;

    fn try_from(value: u16) -> Result<Self, Self::Error> {
        NonZeroU16::new(value)
            .map(Port)
            .ok_or(PortError::Zero)
    }
}

#[derive(Debug, thiserror::Error)]
pub enum PortError {
    #[error("port cannot be zero")]
    Zero,
}

// Usage: validated once, trusted everywhere
let port = Port::try_from(8080)?;
// No need to re-validate `port` anywhere it's used
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `String` for multiple ID types | Create `UserId`, `OrderId`, etc. newtypes |
| Validating in multiple places | Validate once at construction with `nutype` |
| `u64` or `i64` for identifiers | Use `String` - IDs aren't for math |
| `f64` for money | Use `doubloon::Money` or `rust_decimal::Decimal` |
| Passing multiple strings that could be confused | Use newtypes to catch misuse at compile time |

## Anti-Pattern: Primitive Obsession

```rust
// ❌ BAD - can mix up parameters
fn transfer(from_account: String, to_account: String, reference: String) { }

transfer(to_acct, from_acct, ref_id); // Compiles but wrong order!

// ✅ GOOD - compiler catches mistakes
fn transfer(from: AccountId, to: AccountId, reference: TransferId) { }

transfer(to, from, ref_id); // Compile error - wrong types!
```

## Resources

- nutype: https://docs.rs/nutype
- aliri_braid: https://docs.rs/aliri_braid
- derive_more: https://docs.rs/derive_more
- rust_decimal: https://docs.rs/rust_decimal
- doubloon: https://docs.rs/doubloon
- Rust API Guidelines - Type Safety: https://rust-lang.github.io/api-guidelines/type-safety.html
- Rust Design Patterns - Newtype: https://rust-unofficial.github.io/patterns/patterns/behavioural/newtype.html
- Ultimate Guide to Rust Newtypes: https://www.howtocodeit.com/guides/ultimate-guide-rust-newtypes
