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

### Arc (Atomic Reference Counting)

```rust
use std::sync::Arc;

// Arc<T> is Send + Sync if T is Send + Sync
let shared = Arc::new(data);
```

Putting a non-`Send`/`Sync` type in `Arc` doesn't make it thread-safe.

### Mutex (Synchronized Access)

```rust
use std::sync::Mutex;

// Mutex<T> is Send if T: Send
// Mutex<T> is Sync if T: Send (T doesn't need Sync!)
let protected = Mutex::new(data);
```

### Common Pattern: `Arc<Mutex<T>>`

```rust
use std::sync::{Arc, Mutex};

let shared = Arc::new(Mutex::new(HashMap::new()));
let clone = Arc::clone(&shared);

thread::spawn(move || {
    let mut guard = clone.lock().unwrap();
    guard.insert("key", "value");
});
```

### RwLock (Read-Heavy Workloads)

```rust
use std::sync::RwLock;

// RwLock<T> is Send if T: Send
// RwLock<T> is Sync if T: Send + Sync (more restrictive than Mutex!)
let data = RwLock::new(config);
```

**Use when:** Many readers, few writers. Multiple readers can hold the lock simultaneously.

**Bounds difference:** `Mutex<T>: Sync` only needs `T: Send`, but `RwLock<T>: Sync` needs `T: Send + Sync` because multiple threads read `T` simultaneously.

### OnceLock and LazyLock (Lazy Initialization)

```rust
use std::sync::{OnceLock, LazyLock};

// OnceLock - explicitly initialized
static CONFIG: OnceLock<Config> = OnceLock::new();
CONFIG.get_or_init(|| load_config());

// LazyLock - initialized on first access
static REGEX: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\d+$").unwrap()
});
```

Both are `Sync` despite interior mutability because they can only be written once.

## Opting Out with PhantomData

Since stable Rust can't write `impl !Send`, use `PhantomData`:

| PhantomData Type | Effect |
|------------------|--------|
| `PhantomData<*const ()>` | `!Send + !Sync` |
| `PhantomData<Cell<()>>` | `Send + !Sync` |

```rust
use std::marker::PhantomData;

struct NotThreadSafe {
    data: i32,
    _marker: PhantomData<*const ()>,  // !Send + !Sync
}
```

## Async Context: tokio::spawn

### Why Send is Required

`tokio::spawn` requires `Send` because the runtime may move tasks between threads at `.await` points.

A task is `Send` when **all data held across `.await`** is `Send`:

```rust
// ❌ Fails - Rc held across .await
tokio::spawn(async {
    let rc = Rc::new("hello");
    yield_now().await;  // rc lives across .await
    println!("{}", rc);
});

// ✅ Works - Rc dropped before .await
tokio::spawn(async {
    {
        let rc = Rc::new("hello");
        println!("{}", rc);
    }  // rc dropped
    yield_now().await;
});
```

### MutexGuard Across .await

`std::sync::MutexGuard` is `!Send`—it cannot be held across `.await` points:

```rust
// ❌ Fails - guard held across .await
async fn bad(mutex: &Mutex<i32>) {
    let mut lock = mutex.lock().unwrap();
    *lock += 1;
    do_something_async().await;  // Error: future is not Send
}

// ✅ Works - scope the guard
async fn good(mutex: &Mutex<i32>) {
    {
        let mut lock = mutex.lock().unwrap();
        *lock += 1;
    }  // guard dropped before .await
    do_something_async().await;
}
```

**For detailed mutex patterns in async code** (including `tokio::sync::Mutex` and `RobustMutex`), see `async.md`.

### spawn_local for !Send Futures

Use `LocalSet` and `spawn_local` for `!Send` futures:

```rust
use tokio::task::{LocalSet, spawn_local};

let local = LocalSet::new();

local.run_until(async {
    spawn_local(async {
        let rc = Rc::new("hello");
        yield_now().await;
        println!("{}", rc);  // Works!
    }).await.unwrap();
}).await;
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `Rc` in spawned task | Use `Arc` or `spawn_local` |
| `MutexGuard` across `.await` | Scope guard, use `tokio::sync::Mutex`, or see `async.md` |
| Assuming `Arc<T>` is always `Send` | T must also be `Send + Sync` |
| Using `RwLock` when `Mutex` suffices | `RwLock` has stricter bounds (`T: Send + Sync`) |
| Manual `unsafe impl Send` without proof | Only when you can guarantee safety |
| `once_cell` crate for lazy statics | Use `std::sync::LazyLock` (stable since 1.80) |

## Resources

- The Rustonomicon - Send and Sync: https://doc.rust-lang.org/nomicon/send-and-sync.html
- Tokio Tutorial - Spawning: https://tokio.rs/tokio/tutorial/spawning
- Tokio Tutorial - Shared State: https://tokio.rs/tokio/tutorial/shared-state
