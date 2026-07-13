# Testing in Rust

## When to Use This Reference

- Writing unit tests
- Testing async or time-dependent code
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

**Use `cargo nextest run` over `cargo test`.** Nextest is faster, gives better output, and handles test isolation properly. **But nextest does not run doctests** — run `cargo test --doc` separately, or they never execute.

**Use `cargo clippy` over `cargo check`.** Clippy catches more issues at compile time.

## Testing Philosophy

**Test behavior, not implementation.** If you refactor internals and tests break but behavior hasn't changed, the tests were too tightly coupled.

**Test against a known-good oracle; never restate the implementation.** A test that echoes the code's own constants or logic is tautological — it passes by construction and catches nothing. For a port or migration, the previous implementation is the oracle: assert the new code reproduces its observable outputs (counts, totals, classifications).

**Data-dependent tests: gate on presence, and pair with a hermetic fixture.** When a test needs private or `.gitignore`d data, skip it non-silently if the fixture is absent (`eprintln!` a notice and `return`, never a silent pass or a hard panic on a fresh clone). Always pair such a gated test with an always-running synthetic fixture exercising the same code paths — the gated test pins the real numbers, the hermetic test pins the logic.

## Mocking Strategy

**Prefer real implementations over mocks when possible.** Mocks verify that you *call* dependencies correctly, not that the system works.

Use mocks when the real dependency is slow (network, database), has side effects (emails, payments), or when you need error paths that are hard to trigger otherwise. Avoid mocks for pure functions, when an in-memory implementation works (e.g. a `HashMap` instead of a mocked database), or when the mock setup exceeds the code under test.

`mockall` mocks a trait via `#[automock]`, then sets per-call expectations:

```rust
use mockall::{automock, predicate::*};

#[automock]
trait Database {
    fn get_user(&self, id: &str) -> Option<User>;
}

let mut mock = MockDatabase::new();
mock.expect_get_user()
    .with(eq("user123"))
    .returning(|_| Some(User { name: "Alice".into() }));
```

`mockito` stands up an HTTP server and asserts the expected request was made:

```rust
let mut server = mockito::Server::new_async().await;
let mock = server.mock("GET", "/api/users")
    .with_status(200)
    .with_body(r#"{"name": "Alice"}"#)
    .create_async().await;
// ... drive the client against server.url() ...
mock.assert_async().await;
```

## Unit vs Integration Tests

Unit tests (`#[cfg(test)] mod tests` with `use super::*`) can reach private items — use them for internal logic. Integration tests in `tests/` see only the public API; use them for the public contract and multi-crate interactions. If an integration test is awkward to write, treat that as a signal the API itself needs work.

## Time-Dependent Tests

Use `start_paused = true` to control time without real delays:

```rust
use tokio::time::{self, Duration};

#[tokio::test(start_paused = true)]
async fn test_timeout() {
    let start = time::Instant::now();
    time::advance(Duration::from_secs(60)).await;  // no real wait
    assert_eq!(start.elapsed(), Duration::from_secs(60));
}
```

`time::sleep` also completes instantly under a paused clock, so a 1-hour sleep costs nothing.

## Property-Based Testing with proptest

Beyond simple examples, proptest excels at finding edge cases you wouldn't think to test manually.

**Property catalog — common properties to test:**

| Property | Description | Example |
|----------|-------------|---------|
| Roundtrip | `decode(encode(x)) == x` | Serialization, parsing |
| Idempotence | `f(f(x)) == f(x)` | Normalization, formatting |
| Invariant preservation | Property holds before and after | Sorted order, length constraints |
| Commutativity | `f(a, b) == f(b, a)` | Set operations, merging |
| No panic | Function doesn't panic on any input | Parsers, validators |

```rust
use proptest::prelude::*;

proptest! {
    // Validated types reject invalid input and accept valid input
    #[test]
    fn username_validation_is_consistent(s in "\\PC{0,200}") {
        match Username::try_new(&s) {
            Ok(username) => {
                // Valid usernames survive a roundtrip
                assert_eq!(Username::try_new(username.as_str()).unwrap(), username);
            }
            Err(_) => assert!(Username::try_new(&s).is_err()),
        }
    }

    // Serialization roundtrips
    #[test]
    fn json_roundtrip(value in any::<MyType>()) {
        let json = serde_json::to_string(&value).unwrap();
        let decoded: MyType = serde_json::from_str(&json).unwrap();
        assert_eq!(value, decoded);
    }
}
```

## Running Tests

```bash
cargo nextest run                # all tests
cargo nextest run test_name      # a specific test
cargo nextest run parser::       # a module
cargo nextest run --no-capture   # with stdout/stderr
cargo test --doc                 # doctests — nextest does NOT run these
```

## Resources

- cargo-nextest: https://nexte.st
- Tokio Testing: https://docs.rs/tokio/latest/tokio/attr.test.html
- Mockall: https://docs.rs/mockall
- Mockito: https://docs.rs/mockito
- Proptest: https://proptest-rs.github.io/proptest/intro.html
