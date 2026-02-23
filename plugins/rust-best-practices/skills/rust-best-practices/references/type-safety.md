# Type Safety in Rust

## When to Use This Reference

- Creating domain types (user IDs, email addresses)
- Seeing `String` or other primitives where semantic types would be clearer
- Wanting validation at construction time
- Reducing "primitive obsession" anti-pattern
- A value requires context (timezone, locale, unit) to be correctly consumed — embed it in the type

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

### aliri_braid Gotchas

**`new(String)` collision:** The `braid` macro auto-generates `fn new(s: String) -> Self` on every braid type. If you try to define your own zero-argument `new()` constructor (e.g., for generating a random value), you'll get a "duplicate definitions with name `new`" error. Use a distinct name like `generate()` instead:

```rust
#[braid(serde)]
pub struct EventId;

impl EventId {
    // BAD: collides with macro-generated new(String)
    // pub fn new() -> Self { ... }

    // GOOD: distinct name avoids collision
    pub fn generate() -> Self {
        Self::new(ksuid::Ksuid::generate().to_string())
    }
}
```

**Infallible `FromStr` when no validator:** If the braid type has no `validator` attribute, the macro generates an infallible `FromStr` implementation (`Err = Infallible`). Since the parse can never fail, use Rust's irrefutable let pattern — `.unwrap()` compiles but is noisy and misleading:

```rust
// GOOD: irrefutable — compiler confirms this can't fail
let Ok(token) = raw_string.parse::<SessionToken>();

// BAD: unwrap on an infallible Result — noisy and misleading
let token = raw_string.parse::<SessionToken>().unwrap();
```

If the braid type does have a `validator`, `FromStr` is fallible and you should use `?` or `match` normally.

**Owned vs Ref pairs:** Braid generates both `TypeName` (owned, `String`-backed) and `TypeNameRef` (borrowed, `str`-backed). Use `&TypeNameRef` for function parameters to accept both owned and borrowed forms without cloning:

```rust
fn lookup(id: &UserIdRef) -> Option<User> { /* ... */ }

let owned = UserId::generate();
lookup(&owned);           // &UserId derefs to &UserIdRef
lookup(UserIdRef::from_str("abc123"));  // Direct borrow
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

### Context-Carrying Newtypes

When a value requires semantic context to be correctly consumed — a timezone for a datetime, a currency unit for an amount, a display layer for a template — embed that context in the type rather than passing it separately at every call site.

Use method **absence** to enforce categorical distinctions at compile time. Not implementing a method is intentional API design:

```rust
// ❌ BAD - context passed separately; easy to forget, easy to pass the wrong one
fn display_time(dt: DateTime<Utc>, timezone: Option<&str>) { }

// ✅ GOOD - type carries required context; misuse is structurally impossible
pub struct LocatedTime(DateTime<chrono_tz::Tz>);  // anchored to a physical location
pub struct ViewerTime(DateTime<Utc>);             // relative to the viewer's browser

impl LocatedTime {
    pub fn iana_tz(&self) -> &'static str { self.0.timezone().name() }
}

// ViewerTime intentionally has no iana_tz() — misuse won't compile:
fn render_located(t: &LocatedTime) {
    let tz = t.iana_tz(); // ✅ compiles
}
fn render_viewer(t: &ViewerTime) {
    // t.iana_tz();  // ❌ compile error: method not found
}
```

**When to use this pattern:**
- Values that must always be interpreted in a specific context (timezone, locale, unit system)
- Display/template layer types that carry all required rendering context
- Any case where "which category is this value?" matters as much as "what is the value?"

This is "Make Illegal States Unrepresentable" applied to interpretation context rather than data state.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `String` for multiple ID types | Create `UserId`, `OrderId`, etc. newtypes |
| Validating in multiple places | Validate once at construction with `nutype` |
| `u64` or `i64` for identifiers | Use `String` - IDs aren't for math |
| `f64` for money | Use `doubloon::Money` or `rust_decimal::Decimal` |
| Passing multiple strings that could be confused | Use newtypes to catch misuse at compile time |
| Passing required context (timezone, locale) as a separate parameter | Embed context in the type; use method absence to prevent category errors |

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
