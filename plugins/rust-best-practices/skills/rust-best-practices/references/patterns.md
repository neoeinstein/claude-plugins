# Design Patterns in Rust

## When to Use This Reference

- Structuring code for maintainability
- Preventing invalid states
- Managing resources safely
- Applying well-known patterns in Rust idiomatically

## Quick Reference

| Pattern | Use When |
|---------|----------|
| Make Illegal States Unrepresentable | Data has invariants that should always hold |
| Newtype | Need type distinction or validation |
| Typestate | Operations must happen in a specific order (see `api-design.md`) |
| RAII | Resources need deterministic cleanup |
| Builder | Complex object construction (see `api-design.md`) |

## Core Principle

**Make Illegal States Unrepresentable.** Design your types so that invalid data cannot be constructed. If the compiler accepts it, it should be valid.

## Patterns

### Make Illegal States Unrepresentable

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

### Using Enums for Exclusive States

```rust
// ❌ BAD - multiple bools can conflict
struct Connection {
    is_connected: bool,
    is_authenticated: bool,
    is_error: bool,  // Can this be true while connected?
}

// ✅ GOOD - exactly one state at a time
enum ConnectionState {
    Disconnected,
    Connected,
    Authenticated { user: UserId },
    Error { reason: String },
}

struct Connection {
    state: ConnectionState,
}
```

### RAII (Resource Acquisition Is Initialization)

Resources are acquired in constructors and released in destructors. Rust's ownership makes this natural.

```rust
struct TempFile {
    path: PathBuf,
}

impl TempFile {
    fn new() -> std::io::Result<Self> {
        let path = std::env::temp_dir().join(uuid::Uuid::new_v4().to_string());
        std::fs::File::create(&path)?;
        Ok(Self { path })
    }
}

impl Drop for TempFile {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

// File is automatically deleted when TempFile goes out of scope
fn use_temp_file() -> Result<()> {
    let temp = TempFile::new()?;
    // ... use the file ...
    Ok(())
}  // File deleted here, even on early return or panic
```

### Guard Pattern

Use guards to ensure cleanup even on early returns:

```rust
struct MutexGuard<'a, T> {
    mutex: &'a Mutex<T>,
}

impl<T> Drop for MutexGuard<'_, T> {
    fn drop(&mut self) {
        self.mutex.unlock();
    }
}

// Lock is always released when guard is dropped
fn critical_section(mutex: &Mutex<Data>) -> Result<()> {
    let _guard = mutex.lock();
    // ... do work ...
    // Lock released here, even if we return early
}
```

### Extension Traits

Add methods to foreign types without orphan rule issues:

```rust
trait StringExt {
    fn truncate_to_chars(&self, max_chars: usize) -> &str;
}

impl StringExt for str {
    fn truncate_to_chars(&self, max_chars: usize) -> &str {
        match self.char_indices().nth(max_chars) {
            Some((idx, _)) => &self[..idx],
            None => self,
        }
    }
}

// Now available on all &str - safely handles UTF-8
let truncated = "hello world".truncate_to_chars(5); // "hello"
let utf8_safe = "héllo".truncate_to_chars(2);       // "hé" (not a panic!)
```

**Warning:** Naive string slicing like `&s[..n]` panics if `n` splits a multi-byte UTF-8 character. Always use `char_indices()` or similar for safe truncation.

## Anti-Patterns to Avoid

### Stringly Typed Code

```rust
// ❌ BAD - errors are just strings
fn process(command: &str) -> Result<String, String> { }

// ✅ GOOD - typed commands and errors
enum Command { Start, Stop, Restart }

#[derive(Debug, thiserror::Error)]
enum ProcessError {
    #[error("already running")]
    AlreadyRunning,
    #[error("not running")]
    NotRunning,
}

fn process(command: Command) -> Result<(), ProcessError> { }
```

### God Object

```rust
// ❌ BAD - one struct does everything
struct Application {
    config: Config,
    database: Database,
    http_client: HttpClient,
    cache: Cache,
    // ... 20 more fields
}

impl Application {
    fn do_everything(&self) { }
}

// ✅ GOOD - separate concerns
struct UserService { db: Database }
struct NotificationService { http: HttpClient }
struct CacheService { cache: Cache }
```

### Excessive Option/Result Nesting

```rust
// ❌ BAD - deeply nested
fn get_value() -> Option<Result<Option<String>, Error>> { }

// ✅ GOOD - flatten or use custom types
fn get_value() -> Result<Option<String>, Error> { }
// Or
enum GetValueResult { Found(String), NotFound, Error(Error) }
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Boolean fields for exclusive states | Use enum with variants |
| Manual resource cleanup | Use RAII with Drop |
| String for everything | Use newtypes and enums |
| Deeply nested Options/Results | Flatten or use custom types |

## Resources

- Rust Design Patterns Book: https://rust-unofficial.github.io/patterns/
- Anti-patterns: https://rust-unofficial.github.io/patterns/anti_patterns/index.html
- Make Illegal States Unrepresentable: https://corrode.dev/blog/illegal-state/
- Compile-time Invariants: https://corrode.dev/blog/compile-time-invariants/
- Effective Rust: https://effective-rust.com/
