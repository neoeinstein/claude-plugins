# Error Handling in Rust

## When to Use This Reference

- Deciding between `Result` and `panic!`
- Choosing error handling crates (thiserror vs color_eyre)
- Reviewing code with `.unwrap()` or `.expect()` calls
- Designing error types for a library

## Quick Reference

| Context | Approach |
|---------|----------|
| Library code | `thiserror` - typed, specific errors |
| Application code | `color_eyre` (preferred) or `anyhow` |
| Tests | `.unwrap()` is fine |
| Compile-time proven (e.g., regex literals) | `.expect("reason")` acceptable |
| Initialization / startup | `.expect("reason")` acceptable - fail fast |
| Production runtime code | **Never** `.unwrap()` or `.expect()` |

## The Rule

**Libraries:** Return typed errors consumers can match on.
**Applications:** Use `color_eyre::Result` with `.wrap_err()` for context.
**Tests:** `.unwrap()` is fine.
**Initialization:** `.expect("descriptive reason")` acceptable - fail fast on startup.
**Production runtime:** Always use `?` or proper error handling. No `.unwrap()`, no `.expect()`.

## Patterns

### Library Error Type

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum MyError {
    #[error("invalid input: {0}")]
    InvalidInput(String),
    #[error("connection failed")]
    Connection(#[from] std::io::Error),
}
```

### Application Error Handling

```rust
use color_eyre::{eyre::WrapErr, Result};

fn load_config(path: &Path) -> Result<Config> {
    let contents = std::fs::read_to_string(path)
        .wrap_err("failed to read config file")?;
    // ...
}
```

### When .expect() is Acceptable

```rust
// Compile-time proven safe - regex literal is valid
let re = Regex::new(r"^\d+$").expect("valid regex");

// Startup initialization - fail fast if config missing
fn main() -> Result<()> {
    let config = Config::load().expect("config required to start");
    // ...
}
```

### Never in Production Runtime

```rust
// ❌ BAD - runtime code
fn process_request(data: &str) -> Response {
    let parsed = parse(data).unwrap(); // NO
}

// ✅ GOOD - propagate error
fn process_request(data: &str) -> Result<Response> {
    let parsed = parse(data)?;
    // ...
}
```

## STOP and Reconsider

**Before using `.unwrap()` in non-test code:** Can you prove this never fails? If yes, use `.expect("reason it can't fail")`. If no, use `?` or handle the error.

**Before using `panic!()` in library code:** Libraries should return errors, not crash the caller's program. Use `panic!()` only for programming errors that indicate a bug (violated invariants), never for recoverable conditions.

**Before using `.ok()` to discard an error:** Are you sure you don't need to log this? Silently swallowed errors are the hardest bugs to diagnose.

### Infallible Parsing Pattern

When a conversion is infallible (the error type is `Infallible` or `!`), use irrefutable `let` binding instead of `.unwrap()`:

```rust
use std::convert::Infallible;

fn parse_infallible(input: &str) -> Result<String, Infallible> {
    Ok(input.to_uppercase())
}

// ❌ BAD - unwrap on a Result that can never fail
let result = parse_infallible("hello").unwrap();

// ✅ GOOD - irrefutable let binding for Result<T, Infallible>
let Ok(result) = parse_infallible("hello");
// `result` is available directly — no unwrap needed
```

This works because `Infallible` is uninhabited (has no values), so the `Err` case can never occur and the compiler knows the `let Ok(x) = expr;` pattern is irrefutable.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `.unwrap()` or `.expect()` in production runtime | Use `?` or proper error handling |
| `anyhow` in library public API | Use `thiserror` for typed errors |
| Swallowing errors with `.ok()` | Log or propagate |
| Generic error messages | Use `.wrap_err()` to add context |

## Hidden Panic Sources

Some operations panic unexpectedly. Watch for these:

| Operation | Panic Condition | Safe Alternative |
|-----------|-----------------|------------------|
| `&s[..n]` on strings | `n` splits UTF-8 char | `s.get(..n)` or `char_indices()` |
| `vec[i]` | Out of bounds | `vec.get(i)` |
| `slice.split_at(n)` | `n > len` | Check length first |
| Integer arithmetic | Overflow in debug | `checked_add()`, `saturating_add()` |

## Resources

- thiserror: https://docs.rs/thiserror
- color-eyre: https://docs.rs/color-eyre
- anyhow: https://docs.rs/anyhow
- Rust Book - Error Handling: https://doc.rust-lang.org/book/ch09-00-error-handling.html
- Rust by Example - Errors: https://doc.rust-lang.org/rust-by-example/error.html
