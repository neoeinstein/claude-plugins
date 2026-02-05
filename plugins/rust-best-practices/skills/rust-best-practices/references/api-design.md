# API Design in Rust

## When to Use This Reference

- Designing public library APIs
- Creating structs with many optional fields
- Implementing traits for your types
- Naming functions, types, and modules
- Enforcing valid state transitions at compile time

## Quick Reference

| Need | Approach |
|------|----------|
| Complex struct construction | Builder pattern with `typed_builder` |
| Many optional parameters | Builder or struct with defaults |
| Flexible input types | `impl Into<T>` or `impl AsRef<T>` (with care) |
| Enforcing state transitions | Typestate pattern |
| Naming | Follow Rust API Guidelines conventions |

## The Rule

**Design APIs that are hard to misuse.** Use the type system to guide users toward correct usage. Prefer compile-time errors over runtime errors.

## Patterns

### Builder Pattern with typed_builder

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

**Why builders over public structs:**
- Adding new fields with `#[builder(default)]` is non-breaking
- Public structs with all public fields break downstream when fields are added
- Builders guide users through required vs optional fields
- IDE autocomplete shows available options

### Typestate Pattern

Use the type system to enforce valid state transitions at compile time. Each state is a distinct type, and methods only exist on valid states.

```rust
// State marker types
pub struct Uninitialized;
pub struct Ready;
pub struct Running;

pub struct Connection<State> {
    inner: TcpStream,
    _state: PhantomData<State>,
}

impl Connection<Uninitialized> {
    pub fn new(stream: TcpStream) -> Self {
        Self { inner: stream, _state: PhantomData }
    }

    pub fn handshake(self) -> Result<Connection<Ready>> {
        // Perform handshake...
        Ok(Connection { inner: self.inner, _state: PhantomData })
    }
}

impl Connection<Ready> {
    pub fn start(self) -> Connection<Running> {
        Connection { inner: self.inner, _state: PhantomData }
    }
}

impl Connection<Running> {
    pub fn send(&mut self, data: &[u8]) -> Result<()> {
        // Only available when running
    }

    pub fn stop(self) -> Connection<Ready> {
        Connection { inner: self.inner, _state: PhantomData }
    }
}

// Usage - compiler enforces correct order
let conn = Connection::new(stream);
let conn = conn.handshake()?;  // Must handshake first
let mut conn = conn.start();   // Then start
conn.send(b"hello")?;          // Now can send

// conn.handshake(); // Error! Method doesn't exist on Running state
```

**Benefits:**
- Invalid state transitions are compile errors
- Methods only appear in valid states (IDE autocompletion helps users)
- No runtime state checks needed

### Flexible Input with Into

```rust
// Accept anything that can become a String
pub fn set_name(&mut self, name: impl Into<String>) {
    self.name = name.into();
}

// Works with &str, String, Cow<str>, etc.
config.set_name("Alice");
config.set_name(String::from("Bob"));
```

### Flexible Borrowing with AsRef

```rust
// Accept anything that can be borrowed as a path
pub fn read_file(path: impl AsRef<Path>) -> Result<String> {
    std::fs::read_to_string(path.as_ref())
}

// Works with &str, String, PathBuf, &Path
read_file("config.toml")?;
read_file(PathBuf::from("/etc/config"))?;
```

### Avoiding Monomorphization Bloat

`impl Trait` parameters are monomorphized - the compiler generates separate code for each concrete type. This can cause code bloat. Limit bloat by delegating to an inner function:

```rust
// Public API - flexible but thin wrapper
pub fn process(input: impl AsRef<str>) {
    process_inner(input.as_ref())
}

// Private implementation - single concrete version
fn process_inner(input: &str) {
    // All the actual logic here
    // Only one copy of this code exists
}
```

Use `impl Trait` judiciously - it's great for ergonomics but can increase binary size if overused on complex functions.

### Default Implementations

```rust
#[derive(Default)]
pub struct Config {
    pub timeout_ms: u64,
    pub retries: u32,
    pub verbose: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            timeout_ms: 30_000,
            retries: 3,
            verbose: false,
        }
    }
}

// Users can override specific fields
let config = Config {
    verbose: true,
    ..Default::default()
};
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Types, traits | PascalCase | `HttpClient`, `Iterator` |
| Functions, methods | snake_case | `find_user`, `is_empty` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_CONNECTIONS` |
| Modules | snake_case | `http_client` |
| Conversion methods | `as_`, `to_`, `into_` | `as_str()`, `to_string()`, `into_inner()` |
| Getters | field name (no `get_`) | `fn name(&self)` not `fn get_name(&self)` |
| Predicates | `is_`, `has_`, `can_` | `is_empty()`, `has_value()` |

### Conversion Method Prefixes

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

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Public struct with all public fields | Use builder - adding fields breaks downstream |
| `get_name()` method | Use `name()` - Rust doesn't use `get_` prefix |
| Many positional parameters | Use builder pattern |
| `&String` parameter | Use `&str` or `impl AsRef<str>` |
| `&Vec<T>` parameter | Use `&[T]` |
| `impl Trait` on large functions | Delegate to inner function with concrete types |
| Runtime state validation | Use typestate pattern for compile-time checks |
| Returning `impl Trait` when concrete type works | Return concrete type for flexibility |

## Resources

- Rust API Guidelines: https://rust-lang.github.io/api-guidelines/
- API Guidelines Checklist: https://rust-lang.github.io/api-guidelines/checklist.html
- typed_builder: https://docs.rs/typed-builder
- derive_builder: https://docs.rs/derive_builder
- Microsoft Rust Guidelines: https://microsoft.github.io/rust-guidelines/
- Typestate Pattern: https://rust-unofficial.github.io/patterns/patterns/behavioural/typestate.html
