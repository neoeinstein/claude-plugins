# Testing in Rust

## When to Use This Reference

- Writing unit tests
- Testing async code
- Testing time-dependent code
- Mocking dependencies
- Running tests efficiently

## Quick Reference

| Task | Tool |
|------|------|
| Run tests | `cargo nextest run` |
| Check compilation | `cargo clippy` |
| Async tests | `tokio::test` |
| Time mocking | `tokio::test(start_paused = true)` |
| Trait mocking | `mockall` |
| HTTP mocking | `mockito` |
| Property testing | `proptest` |

## The Rule

**Use `cargo nextest run` over `cargo test`.** Nextest is faster, provides better output, and handles test isolation properly.

**Use `cargo clippy` over `cargo check`.** Clippy catches more issues at compile time.

## Testing Philosophy

**Test behavior, not implementation.** Tests should verify what the code does, not how it does it. If you refactor internals and tests break but behavior hasn't changed, the tests were too tightly coupled.

**The testing pyramid in Rust:**
- **Unit tests** (`#[cfg(test)] mod tests`): Fast, test individual functions and types. These are your primary tests.
- **Integration tests** (`tests/` directory): Test the public API of your crate. These verify that modules work together correctly.
- **Doc tests** (code blocks in `///` comments): Serve double duty as documentation examples and tests. Keep them simple and focused on demonstrating usage.

**When to write each type:**
- Unit test: Pure functions, type conversions, validation logic, error cases
- Integration test: Multi-module workflows, public API contracts, behavior that spans several components
- Doc test: Every public function that isn't self-explanatory. These ensure documentation stays accurate.

## Test Strategy

### Integration vs Unit Tests in Rust

In Rust, unit tests have a unique advantage: they can access private items via `use super::*`. This makes them ideal for testing internal logic without exposing it in the public API.

Integration tests (in `tests/`) only see the public API. Use them for:
- Verifying the public contract
- Testing multi-crate interactions
- Ensuring your public API is ergonomic (if a test is awkward to write, the API might need improvement)

### Mocking Strategy

**Prefer real implementations over mocks when possible.** Mocks can give false confidence — they test that you call dependencies correctly, not that the system works.

Use mocks when:
- The real dependency is slow (network, database)
- The real dependency has side effects (sending emails, charging payments)
- You need to test error paths that are hard to trigger with real dependencies

Avoid mocks when:
- The dependency is a pure function or simple data structure
- You can use an in-memory implementation (e.g., `HashMap` instead of a mocked database)
- The mock setup is more complex than the code being tested

### Property-Based Testing with proptest

Beyond simple examples, proptest excels at finding edge cases you wouldn't think to test manually.

**Property catalog — common properties to test:**

| Property | Description | Example |
|----------|-------------|---------|
| Roundtrip | `decode(encode(x)) == x` | Serialization, parsing |
| Idempotence | `f(f(x)) == f(x)` | Normalization, formatting |
| Invariant preservation | Property holds before and after | Sorted order, length constraints |
| Commutativity | `f(a, b) == f(b, a)` | Set operations, merging |
| No panic | Function doesn't panic on any input | Parsers, validators |

**proptest strategies for common Rust types:**

```rust
use proptest::prelude::*;

proptest! {
    // Test that validated types reject invalid input and accept valid input
    #[test]
    fn username_validation_is_consistent(s in "\\PC{0,200}") {
        match Username::try_new(&s) {
            Ok(username) => {
                // Valid usernames should survive a roundtrip
                assert_eq!(Username::try_new(username.as_str()).unwrap(), username);
            }
            Err(_) => {
                // Invalid input should always be rejected
                assert!(Username::try_new(&s).is_err());
            }
        }
    }

    // Test that serialization roundtrips
    #[test]
    fn json_roundtrip(value in any::<MyType>()) {
        let json = serde_json::to_string(&value).unwrap();
        let decoded: MyType = serde_json::from_str(&json).unwrap();
        assert_eq!(value, decoded);
    }
}
```

## Patterns

### Basic Test Structure

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_functionality() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }

    #[test]
    #[should_panic(expected = "division by zero")]
    fn test_panic_case() {
        divide(1, 0);
    }
}
```

### Async Tests with Tokio

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_async_operation() {
        let result = fetch_data().await;
        assert!(result.is_ok());
    }
}
```

### Time-Dependent Tests

Use `start_paused = true` to control time without real delays:

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use tokio::time::{self, Duration};

    #[tokio::test(start_paused = true)]
    async fn test_timeout() {
        let start = time::Instant::now();

        // Advance time without actually waiting
        time::advance(Duration::from_secs(60)).await;

        assert_eq!(start.elapsed(), Duration::from_secs(60));
    }

    #[tokio::test(start_paused = true)]
    async fn test_with_sleep() {
        // This completes instantly because time is paused
        time::sleep(Duration::from_secs(3600)).await;
    }
}
```

### Mocking with mockall

```rust
use mockall::{automock, predicate::*};

#[automock]
trait Database {
    fn get_user(&self, id: &str) -> Option<User>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_with_mock_db() {
        let mut mock = MockDatabase::new();
        mock.expect_get_user()
            .with(eq("user123"))
            .returning(|_| Some(User { name: "Alice".into() }));

        let service = UserService::new(mock);
        let user = service.find_user("user123");

        assert_eq!(user.unwrap().name, "Alice");
    }
}
```

### HTTP Mocking with mockito

```rust
#[cfg(test)]
mod tests {
    use mockito::{Server, Matcher};

    #[tokio::test]
    async fn test_http_client() {
        let mut server = Server::new_async().await;

        let mock = server.mock("GET", "/api/users")
            .with_status(200)
            .with_body(r#"{"name": "Alice"}"#)
            .create_async()
            .await;

        let client = HttpClient::new(&server.url());
        let response = client.get_user().await.unwrap();

        mock.assert_async().await;
        assert_eq!(response.name, "Alice");
    }
}
```

### Property-Based Testing with proptest

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_parse_roundtrip(s in "\\PC*") {
        let parsed = parse(&s);
        if let Ok(value) = parsed {
            let serialized = value.to_string();
            assert_eq!(parse(&serialized), Ok(value));
        }
    }

    #[test]
    fn test_addition_commutative(a in 0i32..1000, b in 0i32..1000) {
        assert_eq!(add(a, b), add(b, a));
    }
}
```

## Test Organization

```
src/
├── lib.rs
├── parser.rs
└── parser/
    └── tests.rs      # Integration tests for parser module

tests/
├── integration.rs    # Integration tests (separate compilation unit)
└── common/
    └── mod.rs        # Shared test utilities
```

### Inline Tests vs Test Files

```rust
// Inline tests - good for unit tests
#[cfg(test)]
mod tests {
    use super::*;
    // Tests here have access to private items
}
```

```rust
// tests/integration.rs - good for integration tests
// Only has access to public API
use mycrate::public_function;

#[test]
fn test_public_api() { }
```

## Running Tests

```bash
# Run all tests with nextest
cargo nextest run

# Run specific test
cargo nextest run test_name

# Run tests in a specific module
cargo nextest run parser::

# Run tests with output
cargo nextest run --no-capture

# Run only doc tests (nextest doesn't run these)
cargo test --doc
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `cargo test` | Use `cargo nextest run` |
| Real sleeps in tests | Use `start_paused = true` |
| Flaky time-based tests | Use tokio time mocking |
| Testing private functions extensively | Test through public API |
| No test isolation | Each test should be independent |
| Forgetting doc tests with nextest | Run `cargo test --doc` separately |

## Resources

- cargo-nextest: https://nexte.st
- Tokio Testing: https://docs.rs/tokio/latest/tokio/attr.test.html
- Mockall: https://docs.rs/mockall
- Mockito: https://docs.rs/mockito
- Proptest: https://proptest-rs.github.io/proptest/intro.html
