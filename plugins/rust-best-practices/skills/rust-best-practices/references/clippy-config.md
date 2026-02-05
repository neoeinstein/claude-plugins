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

## Allowing Lints Appropriately

```rust
// Allow for a single expression
#[allow(clippy::unwrap_used)]
let value = map.get("key").unwrap(); // Justified because...

// Allow for a function
#[allow(clippy::too_many_arguments)]
fn complex_init(/* many args */) { }

// Allow for a module
#[allow(clippy::unwrap_used)]
mod tests { }

// Allow with reason (Rust 1.81+)
#[allow(clippy::unwrap_used, reason = "test code")]
fn test_something() { }
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

## Resources

- Clippy Documentation: https://doc.rust-lang.org/clippy/
- Clippy Lint List: https://rust-lang.github.io/rust-clippy/master/index.html
- Configuring Clippy: https://doc.rust-lang.org/clippy/configuration.html
