# Clippy Configuration

## When to Use This Reference

- A lint fires and you need to decide what to do (fix first — see "Fix First" below)
- Setting up lints for a new project
- Enforcing error handling rules
- Configuring pedantic lints
- Considering suppression in specific contexts (tests, framework constraints)

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

## Responding to Lints: Fix First

**The default response to any lint is to fix the code, not suppress it.** Lints exist to improve code quality. When clippy or rustc flags something, the first question is always "how do I fix this?", never "how do I silence this?"

### The Hierarchy

1. **Fix the code.** This is the right answer ~95% of the time. If clippy says `collapsible_if`, collapse the `if`. If it says `needless_return`, remove the `return`. If it says `manual_let_else`, use `let ... else`.
2. **Restructure if needed.** Some lints (like `too_many_arguments` or `cognitive_complexity`) point to deeper design issues. The fix isn't suppression — it's refactoring.
3. **Suppress only with structural justification.** The *only* acceptable reasons to suppress a lint are constraints you genuinely cannot change — framework signatures, verified false positives, or temporary WIP markers during active development.

### When Suppression Is Justified

| Justification | Example |
|---------------|---------|
| Framework signature constraints | `#[expect(clippy::needless_pass_by_value, reason = "axum handler signature requires owned types")]` |
| Verified false positive in this specific context | `#[expect(clippy::mutable_key_type, reason = "inner field is not mutated after insertion")]` |
| Proven readability gain with specific structural reason | `#[expect(clippy::match_bool, reason = "match arms contain multi-line blocks; if/else less clear here")]` — must be per-instance, not a general policy |
| WIP marker for in-progress code | `#[expect(dead_code, reason = "wiring up in next commit")]` — temporary only |

### When Suppression Is NOT Justified

- "It's just a style lint" — Style lints enforce consistency and often improve readability. Fix it.
- "The code is more readable this way" — The idiomatic form is more readable once you're accustomed to it. If you genuinely believe otherwise for a specific case, that needs a concrete structural reason, not a preference.
- "I don't want to restructure" — If the lint points to a real design issue (too many args, too complex), the answer is restructuring, not suppression.
- "It's a minor lint" — Minor lints have minor fixes. Just do the fix.
- "I'll fix it later" — The fix is almost always smaller than writing the suppression annotation. Do it now.

### STOP — Anti-Rationalization

| Rationalization | Reality |
|-----------------|---------|
| "I'll suppress it and fix it later" | You won't. Fix it now — the fix is almost always smaller than writing the suppression annotation. |
| "The idiomatic form is less readable" | It's less *familiar*, not less readable. `collapsible_if`, `let ... else`, `map_or` — learn the idiom, don't suppress the lint. |
| "It's just cosmetic" | Cosmetic lints have cosmetic fixes. The suppression annotation is more visual noise than the fix itself. |
| "The suggestion changes behavior" | Verify — clippy lints are well-tested. If it truly is a false positive, suppress with a specific reason explaining the semantic difference. |

### Suppression Mechanics: `expect` vs `allow`

**If** you have a valid structural reason to suppress (per the hierarchy above), **always prefer `#[expect(lint)]` over `#[allow(lint)]`.** The `expect` attribute tells the compiler to warn you when the suppression is no longer needed — it's self-cleaning. `#[allow(lint)]` silently suppresses forever and rots.

**Always include a `reason`.** Every lint suppression must explain the *structural constraint* that prevents fixing the code. This makes suppressions reviewable and challengeable — if the constraint no longer holds, remove the annotation.

```rust
// GOOD: structural reason that can't be fixed away
#[expect(clippy::needless_pass_by_value, reason = "axum handler signature requires owned types")]
fn handler(body: Json<Request>) { }

// GOOD: expect with structural reason — self-cleaning AND self-documenting
#[expect(clippy::too_many_arguments, reason = "matches DB schema constructor; builder planned for v2")]
fn complex_init(/* many args */) { }

// BAD: no reason — impossible to evaluate whether this is still justified
#[expect(clippy::too_many_arguments)]
fn complex_init(/* many args */) { }

// BAD: allow silently suppresses forever — you'll never know when it's stale
#[allow(clippy::too_many_arguments)]
fn complex_init(/* many args */) { }

// WORST: suppressing instead of fixing — just collapse the if
#[allow(clippy::collapsible_if)]  // NEVER — just fix the code
```

### `dead_code` Rules

`#[expect(dead_code)]` is a **WIP marker**, not a permanent annotation. It signals "I know this isn't wired up yet, and I want the compiler to tell me when it is."

| Situation | What to do |
|-----------|------------|
| Code you're actively building toward using | `#[expect(dead_code, reason = "...")]` — temporary mid-task marker |
| Code only referenced by tests | It IS dead code. Delete the code. If tests only exercised that dead code, delete them too. If tests are valuable, refactor them to use live code paths instead. |
| Test helper / infrastructure code | Move it behind `#[cfg(test)]` where it belongs, not a `dead_code` suppression |
| Multi-phase work: code needed later but only tested so far | `#[cfg_attr(not(test), expect(dead_code, reason = "..."))]` — still a WIP marker, not permanent |
| **End of a task/PR** | **Zero `dead_code` suppression annotations should remain.** Wire it up or delete it. This includes `cfg_attr` variants. |

```rust
// GOOD mid-task: temporary marker during active development
#[expect(dead_code, reason = "wiring up in the register_routes commit")]
fn new_feature() { /* will be called from main handler next commit */ }

// GOOD mid-task: multi-phase work, tested but not yet called from production
#[cfg_attr(not(test), expect(dead_code, reason = "phase 2 wires this into the API handler"))]
pub(crate) fn short_code(&self) -> &str { /* ... */ }

// GOOD always: test-only helper behind cfg(test)
#[cfg(test)]
fn make_test_fixture() -> Fixture { /* ... */ }

// BAD: permanent suppression hiding actually dead code
#[allow(dead_code)]
fn unused_legacy_function() { }

// BAD: "used in tests" is not a reason to keep dead production code
#[allow(dead_code)]  // "conditionally dead — used in tests"
fn only_called_in_test_module() { }

// BAD at end of task: any dead_code suppression that survived to completion
#[cfg_attr(not(test), expect(dead_code, reason = "exposed for integration tests"))]
pub(crate) fn never_actually_wired_up(&self) -> &str { /* delete this */ }
```

### `dead_code` Anti-Rationalization

| Rationalization | Reality |
|-----------------|---------|
| "Conditionally dead — used in tests" | If ONLY tests call it, it IS dead. Delete it. If tests are valuable, refactor them to use live paths. If it's test infrastructure, move it behind `#[cfg(test)]`. |
| "Field exists but not yet used in template" | Wire it up or remove it. Don't ship dead fields. |
| "I'll use it later" | `expect(dead_code)` is acceptable MID-TASK only. Remove before completing the task. |
| "It's fine, I used `cfg_attr` instead of `allow`" | `cfg_attr(not(test), expect(dead_code))` is a more precise WIP marker, not a permanent pass. Same end-of-task rule: wire it up or delete it. |
| "It's just an `#[allow]`, not a big deal" | `#[allow]` rots silently. Always use `#[expect]` so the compiler cleans up after you. |
| "The reason is obvious from context" | If it's obvious, it's easy to write. Reasons make suppressions reviewable and removable. |
| "The field must match the JSON/SQL schema" | Serde ignores unknown fields. Dead DTO fields aren't safety — they're coupling. Delete the field; comment the schema. See `references/dead-code-in-serde-structs.md`. |

### Justified Suppression Examples

```rust
// Suppress for a single expression — verified safe in context
#[expect(clippy::unwrap_used, reason = "key is inserted three lines above")]
let value = map.get("key").unwrap();

// Test modules get more latitude for panicking operations
#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "test assertions — panics are the point")]
mod tests { }
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
| Suppressing a lint instead of fixing the code | Fix the code. Suppression is a last resort, not the default response. |
| Only running `cargo check` | Use `cargo clippy` |
| Global `#![allow(clippy::all)]` | Fix warnings or allow selectively |
| Ignoring pedantic warnings | Review them — many are valuable |
| Not configuring CI to fail on warnings | Add `-D warnings` flag |
| Using `#[allow(lint)]` instead of `#[expect(lint)]` | `expect` auto-warns when suppression is stale |
| Leaving `#[expect(dead_code)]` after task completion | Wire it up or delete it — zero should remain at end of task |

## Resources

- Clippy Documentation: https://doc.rust-lang.org/clippy/
- Clippy Lint List: https://rust-lang.github.io/rust-clippy/master/index.html
- Configuring Clippy: https://doc.rust-lang.org/clippy/configuration.html
