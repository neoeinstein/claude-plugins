# API Design in Rust

## When to Use This Reference

- Designing public library APIs
- Creating structs with many optional fields
- Enforcing valid state transitions at compile time

## Quick Reference

| Need | Approach |
|------|----------|
| Complex struct construction | Builder pattern with `typed_builder` |
| Many optional parameters | Builder or struct with defaults |
| Enforcing state transitions | Typestate pattern |
| Naming | Follow the [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/) |
| Where public items live, `pub use`, preludes | See `re-exports.md` |

## The Rule

**Design APIs that are hard to misuse.** Use the type system to guide users toward correct usage; prefer compile-time errors over runtime errors.

## Builder Pattern with typed_builder

```rust
use typed_builder::TypedBuilder;

#[derive(TypedBuilder)]
pub struct Request {
    url: String,
    #[builder(default)]
    timeout_ms: Option<u64>,
    #[builder(default = vec![])]
    headers: Vec<(String, String)>,
}

// Required fields enforced at compile time
let req = Request::builder()
    .url("https://example.com".into())
    .timeout_ms(Some(5000))
    .build();
```

**Why builders over public structs:** adding a field with `#[builder(default)]` is non-breaking, whereas a struct with all-public fields breaks every downstream struct-literal and destructuring site the moment you add a field. Builders also guide users through required vs optional fields.

## Typestate Pattern

Each state is a distinct type; methods exist only on the states where they're valid, so invalid transitions are compile errors with no runtime checks.

```rust
pub struct Uninitialized; pub struct Ready; pub struct Running;  // state markers

pub struct Connection<State> {
    inner: TcpStream,
    _state: PhantomData<State>,
}

impl Connection<Uninitialized> {
    pub fn handshake(self) -> Result<Connection<Ready>> { /* ... */ }
}
impl Connection<Ready> {
    pub fn start(self) -> Connection<Running> { /* ... */ }
}
impl Connection<Running> {
    pub fn send(&mut self, data: &[u8]) -> Result<()> { /* only exists here */ }
}

let conn = Connection::new(stream).handshake()?.start();
// conn.handshake();  // Error: method doesn't exist on the Running state
```

## Avoiding Monomorphization Bloat

`impl Trait` parameters are monomorphized — the compiler generates separate code per concrete type. Keep the public signature flexible but funnel into a single concrete inner function:

```rust
// Public API - flexible but a thin wrapper
pub fn process(input: impl AsRef<str>) {
    process_inner(input.as_ref())
}

// Private implementation - one concrete version, one copy of the code
fn process_inner(input: &str) {
    // All the actual logic here
}
```

## Conversion Method Prefixes

| Prefix | Cost | Ownership |
|--------|------|-----------|
| `as_` | Free | Borrowed → Borrowed |
| `to_` | Expensive | Borrowed → Owned |
| `into_` | Variable | Owned → Owned (consumes self) |

```rust
impl MyString {
    fn as_str(&self) -> &str { &self.0 }           // Free borrow
    fn to_uppercase(&self) -> String { ... }       // Allocates new
    fn into_bytes(self) -> Vec<u8> { ... }         // Consumes self
}
```

## Resources

- Rust API Guidelines: https://rust-lang.github.io/api-guidelines/
- typed_builder: https://docs.rs/typed-builder
- Typestate Pattern: https://rust-unofficial.github.io/patterns/patterns/behavioural/typestate.html
- Microsoft Rust Guidelines: https://microsoft.github.io/rust-guidelines/
