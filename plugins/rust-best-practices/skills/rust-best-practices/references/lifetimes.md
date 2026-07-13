# Lifetimes in Rust

## When to Use This Reference

- Compiler errors about lifetime annotations
- Working with `'static` bounds (especially `tokio::spawn`)
- Advanced patterns like HRTBs
- Migrating to Rust 2024 edition

## Quick Reference

| Scenario | Pattern |
|----------|---------|
| Spawned tasks need owned data | Clone/move into task, or use `Arc` |
| Function returns reference from single input | Elision handles it |
| Function returns reference from multiple inputs | Explicit annotation required |
| Closure borrows from arguments | May need HRTB (`for<'a>`) |
| Rust 2024 `impl Trait` captures too much | Use `+ use<>` for precise capture |

## Lifetime Elision

The compiler infers lifetimes by three rules: each input reference gets its own lifetime; a single input lifetime propagates to all outputs; and `&self`'s lifetime propagates to all outputs. Elision fails — requiring explicit annotation — when an output reference can't be traced to a single input (`fn frob(s: &str, t: &str) -> &str`) or has no input at all (`fn get_str() -> &str`). Structs holding references always annotate: `struct Wrapper<'a> { data: &'a str }`.

## When to Use `'static`

### Legitimate Uses

- **Spawned tasks** - `tokio::spawn` requires `'static` futures
- **String literals** - `&'static str`
- **Global/leaked data** - `Box::leak`
- **Thread-safe sharing** - Often with `Arc`

### Owned Data for Tasks

`tokio::spawn` needs `'static`, so borrowed data won't compile — move or clone owned data into the task:

```rust
let data = get_data();
tokio::spawn(async move {
    process(data).await  // data moved into task, not borrowed
});
```

### Anti-Pattern: Overusing `'static`

```rust
// ❌ Overly restrictive - forces the caller's data to be 'static
fn process(data: &'static str) { }

// ✅ Let the caller decide the lifetime
fn process(data: &str) { }
```

### `'static` Misconception

`'static` doesn't mean "lives forever"—it means "**can** live for the entire program if needed." Owned types like `String` satisfy `'static`.

## Higher-Rank Trait Bounds (HRTB)

When a closure must work with **any** lifetime the caller later supplies — not one fixed lifetime — use `for<'a>`, meaning "for all choices of `'a`":

```rust
fn with_callback<F>(f: F)
where
    F: for<'a> Fn(&'a str) -> &'a str
{
    let s = String::from("hello");
    println!("{}", f(&s));
}
```

You'll hit HRTBs with `Fn` traits taking reference parameters, generic code accepting closures that borrow from their arguments, parser combinators, and serialization callbacks.

## Rust 2024 Lifetime Capture Rules

In Rust 2024, `impl Trait` **implicitly captures all in-scope generics, including lifetimes**:

```rust
// Rust 2021: 'a is NOT captured. Rust 2024: 'a IS captured.
fn foo<'a>(x: &'a str) -> impl Sized { }
```

### Precise Capturing with `use<..>` (Rust 1.82+)

```rust
// Capture only specific parameters
fn foo<'a, T>(x: &'a str, y: T) -> impl Sized + use<T> {
    // Only T is captured, not 'a
}

// Capture nothing
fn bar<'a>(x: &'a str) -> impl Sized + use<> {
    42  // Independent of 'a
}
```

The old `impl Sized + Captures<'a>` workaround is no longer needed.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Returning `&str` from multiple `&str` inputs | Add explicit lifetime annotations |
| Assuming `'static` means "never dropped" | Remember owned types are `'static` |
| Fighting borrow checker with references | Consider owned types or `Arc` |
| Confused by HRTB errors | Look for closures borrowing from arguments |

## Resources

- The Rustonomicon - Lifetimes: https://doc.rust-lang.org/nomicon/lifetimes.html
- Rust Edition Guide - 2024: https://doc.rust-lang.org/edition-guide/rust-2024/
- Common Rust Lifetime Misconceptions: https://github.com/pretzelhammer/rust-blog/blob/master/posts/common-rust-lifetime-misconceptions.md
