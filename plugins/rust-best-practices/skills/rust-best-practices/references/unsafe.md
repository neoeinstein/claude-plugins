# Unsafe Code in Rust

## When to Use This Reference

- Deciding whether unsafe is needed
- Writing SAFETY documentation
- Reviewing unsafe code blocks
- Working with FFI or raw pointers
- Running verification tools (Miri)

## Quick Reference

| Unsafe Operation | Common Use Case |
|------------------|-----------------|
| Dereference raw pointer | FFI, data structures |
| Call unsafe function | FFI, unchecked operations |
| Access mutable static | Global state |
| Implement unsafe trait | `Send`, `Sync` |
| Access union fields | FFI, bit manipulation |

## The Rules

**Minimize and encapsulate.** Write the smallest possible unsafe block, wrap it in a safe API.

**Document everything.** `# Safety` section for unsafe functions, `// SAFETY:` comment for unsafe blocks.

**Use module privacy.** The only reliable way to protect invariants is private fields at module boundaries.

## The Five Unsafe Superpowers

Unsafe enables exactly five operations:

1. Dereference a raw pointer
2. Call an unsafe function or method
3. Access or modify a mutable static variable
4. Implement an unsafe trait
5. Access fields of `union`s

## Legitimate Use Cases

- **FFI**: Interacting with C/C++ or other languages
- **Low-level abstractions**: Data structures, standard library internals
- **Hardware interaction**: Embedded, kernel, device drivers
- **Performance-critical code**: When you can prove safety the compiler cannot
- **Concurrency primitives**: Building `Mutex`, `RwLock`, etc.

## Documentation Conventions

### For Unsafe Functions: `# Safety` Section

```rust
/// Converts bytes to a string without UTF-8 validation.
///
/// # Safety
///
/// The caller must ensure the bytes are valid UTF-8.
pub unsafe fn from_utf8_unchecked(bytes: &[u8]) -> &str {
    // ...
}
```

### For Unsafe Blocks: `// SAFETY:` Comment

```rust
pub fn split_at(&self, mid: usize) -> (&str, &str) {
    assert!(self.is_char_boundary(mid));
    // SAFETY: just checked that `mid` is on a char boundary.
    unsafe {
        (self.get_unchecked(0..mid), self.get_unchecked(mid..self.len()))
    }
}
```

Include:
- Which preconditions have been verified
- Which invariants are being relied upon
- Why the operation is valid in this context

## Safe Wrapper Pattern

Write minimal unsafe code, wrap in safe interface:

```rust
// Unsafe FFI
unsafe fn snappy_validate(src: *const u8, len: size_t) -> c_int;

// Safe wrapper - validates safety for all inputs
pub fn validate_compressed_buffer(src: &[u8]) -> bool {
    unsafe {
        snappy_validate(src.as_ptr(), src.len() as size_t) == 0
    }
}
```

## Module Privacy for Soundness

```rust
mod my_vec {
    pub struct Vec<T> {
        ptr: *mut T,
        len: usize,
        cap: usize,  // Private! Safe code outside can't break invariants
    }

    impl<T> Vec<T> {
        pub fn len(&self) -> usize { self.len }
        // Safe API, unsafe internals hidden
    }
}
```

If `cap` were public, safe code could break Vec's invariants and cause UB.

## Common Operations

### Raw Pointers

- Creating is safe; **dereferencing** requires unsafe
- No automatic cleanup
- Can be null, dangling, or unaligned

### NonNull<T> (Preferred Over Raw Pointers)

`NonNull<T>` is a non-null pointer with covariance. Prefer it over `*mut T`:

```rust
use std::ptr::NonNull;

struct MyBox<T> {
    ptr: NonNull<T>,  // Guaranteed non-null, covariant
}

impl<T> MyBox<T> {
    fn new(value: T) -> Self {
        let ptr = Box::into_raw(Box::new(value));
        // SAFETY: Box::into_raw never returns null
        Self { ptr: unsafe { NonNull::new_unchecked(ptr) } }
    }
}
```

### MaybeUninit<T> (Uninitialized Memory)

**Never use `mem::uninitialized()`**—it's deprecated and causes immediate UB for many types.

```rust
use std::mem::MaybeUninit;

// ✅ GOOD - proper uninitialized memory handling
let mut value: MaybeUninit<i32> = MaybeUninit::uninit();
unsafe {
    value.as_mut_ptr().write(42);
    let initialized = value.assume_init();
}

// Array initialization pattern
let mut array: [MaybeUninit<String>; 10] = unsafe {
    MaybeUninit::uninit().assume_init()
};

for (i, elem) in array.iter_mut().enumerate() {
    elem.write(format!("item {}", i));
}

// SAFETY: All elements initialized
let array: [String; 10] = unsafe {
    std::mem::transmute(array)
};
```

### Pointer Read/Write Operations

Use `ptr::read`/`ptr::write` instead of raw dereference for:
- Potentially unaligned data
- Moving out of a location without dropping

```rust
use std::ptr;

// Move value out without dropping the source
let value = unsafe { ptr::read(src) };

// Write without dropping the destination's old value
unsafe { ptr::write(dst, value) };

// For unaligned pointers
unsafe {
    let value = ptr::read_unaligned(unaligned_ptr);
    ptr::write_unaligned(unaligned_dst, value);
}
```

### Transmute

`mem::transmute` reinterprets bits. Extremely dangerous.

**Critical rules:**
- **Never** transmute `&T` to `&mut T` - always UB
- Don't create invalid states (e.g., `3` as `bool`)
- Only transmute between types with guaranteed layout (`repr(C)`, `repr(transparent)`)

**Safer alternatives:** `as` casts, `from_ne_bytes`/`to_ne_bytes`, `bytemuck` crate

### FFI (Rust 2024)

```rust
// Rust 2024 requires `unsafe` on extern blocks
#[link(name = "snappy")]
unsafe extern "C" {
    fn snappy_max_compressed_length(source_length: size_t) -> size_t;
}
```

Guidelines:
- Use `#[repr(C)]` for structs crossing FFI
- Use `CString`/`CStr` for NUL-terminated strings
- Wrap foreign functions in safe Rust APIs

## STOP and Reconsider

**Before writing `unsafe` without a `// SAFETY:` comment:** Write the SAFETY comment first. If you cannot clearly articulate what invariants the unsafe code upholds and what preconditions must be true, the code is not safe to write. The comment is not documentation overhead — it's the proof that you've thought through the safety argument.

```rust
// ❌ BAD - no safety argument
unsafe { ptr.read() }

// ✅ GOOD - safety argument documented
// SAFETY: `ptr` was obtained from `Box::into_raw` and has not been
// deallocated. The pointer is properly aligned for `T` and the
// pointed-to value is initialized.
unsafe { ptr.read() }
```

**Before using `mem::transmute`:** There is almost certainly a safer alternative. Use `as` casts for numeric conversions, `from_ne_bytes`/`to_ne_bytes` for byte reinterpretation, `bytemuck` or `zerocopy` for zero-copy type punning with safety checks. `transmute` is the nuclear option — only reach for it when nothing else works AND you have a `#[repr(C)]` or `#[repr(transparent)]` guarantee.

**Before marking a type as `unsafe impl Send` or `unsafe impl Sync`:** Can you prove the type is actually safe to send/share across threads? The compiler didn't implement these traits automatically for a reason. Document exactly why the implementation is sound.

## Anti-Patterns

| Anti-Pattern | Problem |
|--------------|---------|
| Large unsafe blocks | Impossible to audit |
| Missing SAFETY comments | Undocumented invariants |
| `unsafe` for "performance" without measurement | Often unnecessary |
| Trusting arbitrary safe code | Unsafe should trust *specific* safe code |
| Using `transmute` when safer alternatives exist | Prefer `as`, `from_bytes` |
| `mem::uninitialized()` | Deprecated, causes UB—use `MaybeUninit` |
| Raw `*mut T` when null is impossible | Use `NonNull<T>` |
| Dereferencing unaligned pointers | Use `ptr::read_unaligned` |

## Verification Tools

### Miri

Primary UB detection tool. Detects:
- Out-of-bounds access, use-after-free
- Invalid use of uninitialized data
- Misaligned accesses
- Invalid type invariants
- Data races
- Memory leaks

```bash
rustup +nightly component add miri
cargo +nightly miri test
```

**Limitations:** Tests one execution path, cannot prove soundness, limited platform API support.

### Sanitizers

```bash
RUSTFLAGS="-Z sanitizer=address" cargo +nightly test
```

| Sanitizer | Detects |
|-----------|---------|
| AddressSanitizer | Memory errors, buffer overflows |
| ThreadSanitizer | Data races |
| MemorySanitizer | Uninitialized reads |

Run sanitizers even if your crate doesn't use unsafe—dependencies might.

## Rust 2024 Changes

| Change | Description |
|--------|-------------|
| `unsafe_op_in_unsafe_fn` | Warns by default; unsafe ops need explicit `unsafe {}` blocks |
| `unsafe extern` | `extern` blocks must be marked `unsafe` |
| Unsafe attributes | `#[no_mangle]`, `#[link_section]` require `unsafe(...)` |
| `std::env::set_var` | Now requires unsafe |

## Resources

- The Rustonomicon: https://doc.rust-lang.org/nomicon/
- Rust API Guidelines - Unsafe: https://rust-lang.github.io/api-guidelines/documentation.html
- Miri: https://github.com/rust-lang/miri
