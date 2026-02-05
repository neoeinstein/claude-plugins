# Lifetimes in Rust

## When to Use This Reference

- Compiler errors about lifetime annotations
- Understanding elision rules
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

## Lifetime Elision Rules

The compiler applies three rules to infer lifetimes:

### Rule 1: Each Input Gets Its Own Lifetime

```rust
fn foo(x: &str, y: &str)
// becomes
fn foo<'a, 'b>(x: &'a str, y: &'b str)
```

### Rule 2: Single Input → All Outputs

```rust
fn foo(x: &str) -> &str
// becomes
fn foo<'a>(x: &'a str) -> &'a str
```

### Rule 3: `&self` → All Outputs

```rust
fn foo(&self) -> &T
// becomes
fn foo<'a>(&'a self) -> &'a T
```

### When Elision Fails

```rust
fn get_str() -> &str;                    // ❌ No input lifetime
fn frob(s: &str, t: &str) -> &str;       // ❌ Ambiguous source
```

Both require explicit annotations.

### Structs Always Need Annotations

```rust
struct Wrapper<'a> {
    data: &'a str,  // Required
}
```

## When to Use `'static`

### Legitimate Uses

- **Spawned tasks** - `tokio::spawn` requires `'static` futures
- **String literals** - `&'static str`
- **Global/leaked data** - `Box::leak`
- **Thread-safe sharing** - Often with `Arc`

### Common Pattern: Owned Data for Tasks

```rust
// ❌ Won't compile - borrowed data isn't 'static
let data = get_data();
tokio::spawn(async move {
    process(&data).await
});

// ✅ Clone/own the data
let data = get_data();
tokio::spawn(async move {
    process(data).await  // data moved into task
});
```

### Anti-Pattern: Overusing `'static`

```rust
// ❌ Overly restrictive
fn process(data: &'static str) { }

// ✅ Let caller decide lifetime
fn process(data: &str) { }
```

### `'static` Misconception

`'static` doesn't mean "lives forever"—it means "**can** live for the entire program if needed." Owned types like `String` satisfy `'static`.

## Higher-Rank Trait Bounds (HRTB)

### The Problem

When a closure needs to work with **any** lifetime:

```rust
// What lifetime goes here? It depends on when call() is invoked!
impl<F> Closure<F>
where
    F: Fn(&'??? (u8, u16)) -> &'??? u8
```

### The Solution: `for<'a>`

```rust
impl<F> Closure<F>
where
    for<'a> F: Fn(&'a (u8, u16)) -> &'a u8
```

`for<'a>` means "for all choices of `'a`"—the function works with any lifetime.

### Common HRTB Patterns

**Callbacks that borrow from arguments:**

```rust
fn with_callback<F>(f: F)
where
    F: for<'a> Fn(&'a str) -> &'a str
{
    let s = String::from("hello");
    println!("{}", f(&s));
}
```

### When You'll Encounter HRTBs

- `Fn` traits with reference parameters
- Generic code accepting closures that borrow from arguments
- Parser combinators
- Database/serialization callbacks

## Rust 2024 Lifetime Capture Rules

### What Changed

In Rust 2024, all in-scope generics (including lifetimes) are **implicitly captured** by `impl Trait`:

```rust
// Rust 2021: 'a is NOT captured
fn foo<'a>(x: &'a str) -> impl Sized { }

// Rust 2024: 'a IS captured
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

### Migration from Rust 2021

Old workarounds can be removed:

```rust
// Rust 2021 workaround (no longer needed)
fn foo<'a>(x: &'a str) -> impl Sized + Captures<'a> { }

// Rust 2024 - just works
fn foo<'a>(x: &'a str) -> impl Sized { }
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Returning `&str` from multiple `&str` inputs | Add explicit lifetime annotations |
| Assuming `'static` means "never dropped" | Remember owned types are `'static` |
| Fighting borrow checker with references | Consider owned types or `Arc` |
| Overusing `'static` bounds | Let caller decide lifetime |
| Confused by HRTB errors | Look for closures borrowing from arguments |

## Resources

- The Rustonomicon - Lifetimes: https://doc.rust-lang.org/nomicon/lifetimes.html
- Rust Edition Guide - 2024: https://doc.rust-lang.org/edition-guide/rust-2024/
- Common Rust Lifetime Misconceptions: https://github.com/pretzelhammer/rust-blog/blob/master/posts/common-rust-lifetime-misconceptions.md
