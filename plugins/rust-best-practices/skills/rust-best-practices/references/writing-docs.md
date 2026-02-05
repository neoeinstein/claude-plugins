# Writing Documentation

## When to Use This Reference

- Documenting public APIs
- Writing doc comments for functions and types
- Creating examples in documentation
- Setting up doc tests

## Quick Reference

| Syntax | Use |
|--------|-----|
| `///` | Document the following item |
| `//!` | Document the enclosing item (module/crate) |
| `` `code` `` | Inline code |
| ` ```rust ` | Code block (tested by default) |
| `# hidden line` | Hide line in rendered docs but include in tests |

## The Rule

**Document public APIs.** Every public function, type, and module should have documentation explaining what it does, not how it does it. Internal implementation details don't need excessive documentation if the code is clear.

## Patterns

### Function Documentation

```rust
/// Parses a configuration file and returns the settings.
///
/// # Arguments
///
/// * `path` - Path to the configuration file
///
/// # Errors
///
/// Returns an error if the file cannot be read or parsed.
///
/// # Examples
///
/// ```
/// let config = parse_config("config.toml")?;
/// assert_eq!(config.timeout, 30);
/// # Ok::<(), Box<dyn std::error::Error>>(())
/// ```
pub fn parse_config(path: impl AsRef<Path>) -> Result<Config> {
    // ...
}
```

### Type Documentation

```rust
/// A user account in the system.
///
/// Users are identified by their unique [`UserId`] and can have
/// various roles assigned via [`UserRole`].
///
/// # Examples
///
/// ```
/// let user = User::new("alice", Role::Admin);
/// assert!(user.can_edit());
/// ```
pub struct User {
    /// The user's unique identifier.
    pub id: UserId,
    /// The user's display name.
    pub name: String,
    /// The user's assigned role.
    pub role: UserRole,
}
```

### Module Documentation

```rust
//! # HTTP Client
//!
//! This module provides an async HTTP client for making requests.
//!
//! ## Quick Start
//!
//! ```
//! use mylib::http::Client;
//!
//! let client = Client::new();
//! let response = client.get("https://example.com").await?;
//! # Ok::<(), Box<dyn std::error::Error>>(())
//! ```

mod client;
mod request;
mod response;
```

### Hiding Boilerplate in Examples

Use `#` to hide lines that are necessary for compilation but clutter the example:

```rust
/// Connects to the database.
///
/// # Examples
///
/// ```
/// # use mylib::Database;
/// # fn main() -> Result<(), Box<dyn std::error::Error>> {
/// let db = Database::connect("postgres://localhost/mydb")?;
/// db.query("SELECT 1")?;
/// # Ok(())
/// # }
/// ```
pub fn connect(url: &str) -> Result<Database> { }
```

The rendered documentation shows only:
```rust
let db = Database::connect("postgres://localhost/mydb")?;
db.query("SELECT 1")?;
```

### Linking to Other Items

```rust
/// Converts this [`User`] into a [`UserDto`] for serialization.
///
/// See also: [`User::from_dto`] for the reverse operation.
pub fn to_dto(&self) -> UserDto { }
```

## Doc Test Configuration

### Ignoring Tests

```rust
/// ```ignore
/// // This example won't be tested
/// let x = something_that_cant_compile();
/// ```
```

### Expecting Failure

```rust
/// ```should_panic
/// panic!("This should panic");
/// ```
```

### Compile-Only (No Run)

```rust
/// ```no_run
/// // Compiles but doesn't run (useful for examples needing external resources)
/// let db = Database::connect("postgres://prod-server/db")?;
/// ```
```

## Section Conventions

| Section | When to Use |
|---------|-------------|
| `# Examples` | Always include for public APIs |
| `# Errors` | Document error conditions |
| `# Panics` | Document panic conditions |
| `# Safety` | Required for `unsafe` functions |
| `# Arguments` | When parameters need explanation |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Documenting implementation details | Document behavior, not implementation |
| Missing examples | Add `# Examples` section |
| Broken doc links | Use `` [`Type`] `` syntax |
| Untested examples | Run `cargo test --doc` |
| Over-documenting private code | Focus on public API |

## Running Doc Tests

```bash
# Run all doc tests
cargo test --doc

# Run doc tests for specific crate
cargo test --doc -p mycrate
```

## Resources

- Rustdoc Book: https://doc.rust-lang.org/rustdoc/
- Rust API Guidelines - Documentation: https://rust-lang.github.io/api-guidelines/documentation.html
