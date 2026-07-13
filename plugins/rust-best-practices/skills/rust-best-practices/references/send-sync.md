# Send and Sync Traits

## When to Use This Reference

- Compiler errors about `Send` or `Sync` bounds
- Understanding why `tokio::spawn` requires `Send`
- Making custom types thread-safe
- Working with `!Send` types like `Rc`

## Quick Reference

| Type | Send | Sync | Why |
|------|------|------|-----|
| `Rc<T>` | ❌ | ❌ | Unsynchronized reference count |
| `Arc<T>` | ✅* | ✅* | Atomic reference count (*if T is Send+Sync) |
| `RefCell<T>` | ✅ | ❌ | Runtime borrow checking not thread-safe |
| `Cell<T>` | ✅ | ❌ | Interior mutability without sync |
| `Mutex<T>` | ✅* | ✅* | *if T: Send (T doesn't need Sync!) |
| `RwLock<T>` | ✅* | ✅* | *if T: Send+Sync (more restrictive than Mutex) |
| `MutexGuard<T>` | ❌ | ✅ | Cannot send lock to another thread |
| `OnceLock<T>` | ✅* | ✅* | Write-once, *if T is |
| `*const T`, `*mut T` | ❌ | ❌ | No safety guarantees |

## Definitions

**`Send`**: Safe to transfer ownership to another thread.

**`Sync`**: Safe to share references between threads. Precisely: **T is `Sync` if and only if `&T` is `Send`**.

Both are marker traits (no methods) and unsafe traits—incorrectly implementing them causes UB.

## Auto-Trait Behavior

The compiler implements `Send` and `Sync` automatically:

| Type | Rule |
|------|------|
| Structs, enums, tuples | Implement if **all fields** do |
| Closures | Implement if **all captured values** do |
| `&T`, `&mut T`, `[T]` | Implement if `T` does |
| Function pointers | Always implement |

**Key insight:** Types composed entirely of `Send`/`Sync` types are automatically `Send`/`Sync`.

## Making Types Thread-Safe

### Arc and Arc<Mutex<T>>

```rust
use std::sync::{Arc, Mutex};

// Arc<T> is Send + Sync only if T is Send + Sync
let shared = Arc::new(Mutex::new(HashMap::new()));
let clone = Arc::clone(&shared);
thread::spawn(move || {
    clone.lock().unwrap().insert("key", "value");
});
```

Putting a non-`Send`/`Sync` type in `Arc` doesn't make it thread-safe.

### Mutex vs RwLock

`Mutex<T>` is `Sync` if `T: Send` (T doesn't need `Sync`). `RwLock<T>` suits read-heavy workloads — many readers can hold the lock at once — but is `Sync` only if `T: Send + Sync`.

**Bounds difference:** `Mutex<T>: Sync` only needs `T: Send`, but `RwLock<T>: Sync` needs `T: Send + Sync` because multiple threads read `T` simultaneously.

### OnceLock and LazyLock (Lazy Statics)

```rust
use std::sync::{OnceLock, LazyLock};

static CONFIG: OnceLock<Config> = OnceLock::new();          // explicit init
static REGEX: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"^\d+$").unwrap());        // init on first access
```

Both are `Sync` despite interior mutability because they can only be written once. Use `std::sync::LazyLock` (stable since 1.80), not the `once_cell` crate.

## Opting Out with PhantomData

Since stable Rust can't write `impl !Send`, use `PhantomData`:

| PhantomData Type | Effect |
|------------------|--------|
| `PhantomData<*const ()>` | `!Send + !Sync` |
| `PhantomData<Cell<()>>` | `Send + !Sync` |

```rust
struct NotThreadSafe {
    data: i32,
    _marker: PhantomData<*const ()>,  // !Send + !Sync
}
```

## Async Context: tokio::spawn

`tokio::spawn` requires `Send` because the runtime may move tasks between threads at `.await` points. A task is `Send` only when **all data held across `.await`** is `Send`:

```rust
// ❌ Fails - Rc held across .await makes the whole future !Send
tokio::spawn(async {
    let rc = Rc::new("hello");
    yield_now().await;  // rc lives across .await
    println!("{}", rc);
});
```

Drop the `!Send` value before the `.await`, or use `LocalSet` + `spawn_local` to run `!Send` futures on a single thread.

**`MutexGuard` across `.await`:** `std::sync::MutexGuard` is `!Send` and cannot be held across an await point — see `async.md` for the full mutex treatment (including `tokio::sync::Mutex` and `RobustMutex`).

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `Rc` in spawned task | Use `Arc` or `spawn_local` |
| `MutexGuard` across `.await` | Scope the guard, use `tokio::sync::Mutex`, or see `async.md` |
| Assuming `Arc<T>` is always `Send` | T must also be `Send + Sync` |
| Using `RwLock` when `Mutex` suffices | `RwLock` has stricter bounds (`T: Send + Sync`) |
| Manual `unsafe impl Send` without proof | Only when you can guarantee safety |
| `once_cell` crate for lazy statics | Use `std::sync::LazyLock` (stable since 1.80) |

## Resources

- The Rustonomicon - Send and Sync: https://doc.rust-lang.org/nomicon/send-and-sync.html
- Tokio Tutorial - Spawning: https://tokio.rs/tokio/tutorial/spawning
- Tokio Tutorial - Shared State: https://tokio.rs/tokio/tutorial/shared-state
