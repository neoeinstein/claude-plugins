# Clippy Configuration

## When to Use This Reference

- Setting up lints for a new project
- Enforcing error handling rules
- Configuring pedantic lints
- Allowing lints in specific contexts (tests, examples)

## Quick Reference

| Lint Group | Purpose |
|------------|---------|
| `clippy::all` | Default lints - generally good defaults |
| `clippy::pedantic` | Stricter lints - may have false positives |
| `clippy::restriction` | Very strict - enable selectively |
| `clippy::nursery` | Experimental - use with caution |

## The Rule

**Use `cargo clippy` instead of `cargo check`.** Clippy catches more issues at compile time. Configure it to enforce your team's standards.

## Recommended Configuration

### Cargo.toml Lint Configuration

```toml
[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
# Deny unwrap in production code, warn on expect (acceptable for init)
unwrap_used = "deny"
expect_used = "warn"

# Good pedantic lints to enable
pedantic = { level = "warn", priority = -1 }
must_use_candidate = "warn"
missing_errors_doc = "warn"
missing_panics_doc = "warn"

# Allow in specific cases (override at module level)
module_name_repetitions = "allow"
```

### Per-Module Overrides

```rust
// In test modules, allow unwrap
#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    // Tests can use .unwrap() freely
}

// In main.rs or initialization code
#[allow(clippy::expect_used)]
fn main() -> Result<()> {
    let config = Config::load().expect("config required to start");
    // ...
}
```

## Key Restriction Lints

These are off by default but worth enabling:

| Lint | Purpose |
|------|---------|
| `clippy::unwrap_used` | Prevents `.unwrap()` |
| `clippy::expect_used` | Prevents `.expect()` |
| `clippy::panic` | Prevents `panic!` macro |
| `clippy::todo` | Prevents `todo!` macro |
| `clippy::unimplemented` | Prevents `unimplemented!` macro |
| `clippy::dbg_macro` | Prevents `dbg!` macro in production |
| `clippy::print_stdout` | Prevents `println!` (use logging instead) |

## Useful Pedantic Lints

These are included in `clippy::pedantic` and are usually helpful:

| Lint | Purpose |
|------|---------|
| `clippy::must_use_candidate` | Suggest `#[must_use]` on functions |
| `clippy::missing_errors_doc` | Document error conditions |
| `clippy::missing_panics_doc` | Document panic conditions |
| `clippy::doc_markdown` | Proper markdown in docs |
| `clippy::needless_pass_by_value` | Suggest borrowing instead |
| `clippy::redundant_closure_for_method_calls` | Simplify closures |

## Lint Suppression: `expect` vs `allow`

**Always prefer `#[expect(lint)]` over `#[allow(lint)]`.** The `expect` attribute tells the compiler to warn you when the suppression is no longer needed — it's self-cleaning. `#[allow(lint)]` silently suppresses forever and rots.

**Always include a `reason`.** Every lint suppression must explain *why* it's acceptable. This makes suppressions reviewable and challengeable — if the reason no longer holds, remove the annotation.

```rust
// GOOD: expect with reason — self-cleaning AND self-documenting
#[expect(clippy::too_many_arguments, reason = "builder pattern planned for v2")]
fn complex_init(/* many args */) { }

// BAD: no reason — impossible to evaluate whether this is still justified
#[expect(clippy::too_many_arguments)]
fn complex_init(/* many args */) { }

// BAD: allow silently suppresses forever — you'll never know when it's stale
#[allow(clippy::too_many_arguments)]
fn complex_init(/* many args */) { }
```

### `dead_code` Rules

`#[expect(dead_code)]` is a **WIP marker**, not a permanent annotation. It signals "I know this isn't wired up yet, and I want the compiler to tell me when it is."

| Situation | What to do |
|-----------|------------|
| Code you're actively building toward using | `#[expect(dead_code)]` — temporary, must be removed by end of task |
| Code only referenced by tests | It IS dead code. Delete the code (and probably the tests). |
| Test helper that exists for `#[cfg(test)]` modules | Use `#[cfg(test)]` on the helper itself, not a `dead_code` suppression |
| Code that must exist for non-test builds but is only exercised in tests | `#[cfg_attr(not(test), expect(dead_code))]` |
| End of a task/PR | **Zero** `expect(dead_code)` annotations should remain. Wire it up or delete it. |

```rust
// GOOD: temporary marker during active development, with reason
#[expect(dead_code, reason = "wiring up in the register_routes commit")]
fn new_feature() { /* will be called from main handler next commit */ }

// GOOD: test-only helper
#[cfg(test)]
fn make_test_fixture() -> Fixture { /* ... */ }

// GOOD: exists in non-test builds, only exercised in tests
#[cfg_attr(not(test), expect(dead_code, reason = "exposed for integration tests"))]
pub(crate) fn short_code(&self) -> &str { /* ... */ }

// BAD: permanent suppression hiding actually dead code
#[allow(dead_code)]
fn unused_legacy_function() { }

// BAD: "used in tests" is not a reason to keep dead production code
#[allow(dead_code)]  // "conditionally dead — used in tests"
fn only_called_in_test_module() { }
```

### STOP — Anti-Rationalization

| Rationalization | Reality |
|-----------------|---------|
| "Conditionally dead — used in tests" | If ONLY tests call it, it IS dead. Delete it or `#[cfg(test)]` the helper. |
| "Field exists but not yet used in template" | Wire it up or remove it. Don't ship dead fields. |
| "I'll use it later" | `expect(dead_code)` is acceptable MID-TASK only. Remove before completing the task. |
| "It's just an `#[allow]`, not a big deal" | `#[allow]` rots silently. Always use `#[expect]` so the compiler cleans up after you. |
| "The reason is obvious from context" | If it's obvious, it's easy to write. Reasons make suppressions reviewable and removable. |

### Other Lint Suppression Patterns

```rust
// Suppress for a single expression
#[expect(clippy::unwrap_used, reason = "key is inserted three lines above")]
let value = map.get("key").unwrap();

// Suppress for a module (tests get more latitude)
#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "test assertions — panics are the point")]
mod tests { }

// Framework constraints
#[expect(clippy::needless_pass_by_value, reason = "axum handler signature requires owned types")]
fn handler(req: Request) { }
```

## CI Configuration

```yaml
# GitHub Actions example
- name: Clippy
  run: cargo clippy --all-targets --all-features -- -D warnings
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Only running `cargo check` | Use `cargo clippy` |
| Global `#![allow(clippy::all)]` | Fix warnings or allow selectively |
| Ignoring pedantic warnings | Review them - many are valuable |
| Not configuring CI to fail on warnings | Add `-D warnings` flag |
| Using `#[allow(lint)]` instead of `#[expect(lint)]` | `expect` auto-warns when suppression is stale |
| Leaving `#[expect(dead_code)]` after task completion | Wire it up or delete it — zero should remain at end of task |

## Resources

- Clippy Documentation: https://doc.rust-lang.org/clippy/
- Clippy Lint List: https://rust-lang.github.io/rust-clippy/master/index.html
- Configuring Clippy: https://doc.rust-lang.org/clippy/configuration.html
