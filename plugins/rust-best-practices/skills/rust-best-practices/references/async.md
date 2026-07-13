# Async Patterns in Rust

## When to Use This Reference

- Using `tokio::select!` and need cancellation safety
- Spawning tasks, choosing between `spawn` and `spawn_blocking`
- Deciding between channels and shared state
- Managing task groups with structured concurrency
- Using async traits

## Quick Reference

| Task | Tool |
|------|------|
| Dynamic task groups | `JoinSet` |
| Task group with memory cleanup | `TaskTracker` (tokio-util) |
| Actor pattern | `mpsc` + `oneshot` for responses |
| Blocking IO (filesystem, diesel) | `spawn_blocking` |
| CPU-bound parallel work | `rayon` with oneshot channel |
| Forever-running background work | `std::thread::spawn` |

## The Rules

**Never block >100μs without `.await`.** If you do, use `spawn_blocking` or `rayon`.

**Know your cancellation safety.** In `select!`, only use methods that are cancellation-safe.

**Use the right Mutex.** See Mutex comparison below—wrong choice causes deadlocks or lost wake-ups.

## Cancellation Safety

### Safe to Use in `select!`

- `tokio::sync::mpsc::Receiver::recv`
- `tokio::sync::broadcast::Receiver::recv`
- `tokio::sync::watch::Receiver::changed`
- `tokio::net::TcpListener::accept`
- `tokio::io::AsyncReadExt::read` / `read_buf`
- `tokio::io::AsyncWriteExt::write` / `write_buf`
- `tokio_stream::StreamExt::next`
- `JoinSet::join_next`

### NOT Safe (Data Loss Risk)

- `tokio::io::AsyncReadExt::read_exact`, `read_to_end`, `read_to_string`
- `tokio::io::AsyncWriteExt::write_all`

### NOT Safe (Queue Position Loss)

- `tokio::sync::Mutex::lock`
- `tokio::sync::RwLock::read` / `write`
- `tokio::sync::Semaphore::acquire`
- `tokio::sync::Notify::notified`

### Anti-Pattern: Racy Preconditions

```rust
// ❌ BAD - race condition between check and select!
while !sleep.is_elapsed() {
    tokio::select! {
        _ = &mut sleep, if !sleep.is_elapsed() => { break; }
        _ = some_async_work() => { /* ... */ }
    }
}

// ✅ GOOD - let select! handle completion
loop {
    tokio::select! {
        _ = &mut sleep => { break; }
        _ = some_async_work() => { /* ... */ }
    }
}
```

### Biased Select for Priority

By default, `select!` picks randomly when multiple branches are ready. Use `biased` for deterministic priority:

```rust
tokio::select! {
    biased;  // Check branches in order

    _ = shutdown.recv() => {
        // Always checked first - ensures shutdown isn't starved
        break;
    }
    msg = rx.recv() => {
        handle(msg);
    }
}
```

## Structured Concurrency

### JoinSet for Dynamic Task Groups

```rust
use tokio::task::JoinSet;

let mut set = JoinSet::new();
for i in 0..10 {
    set.spawn(async move { i });
}
while let Some(res) = set.join_next().await {
    let idx = res?;
}
// All remaining tasks aborted when JoinSet dropped
```

### `join!` vs `spawn`

| Aspect | `tokio::join!` | `tokio::spawn` |
|--------|---------------|----------------|
| Execution | Same task, concurrent | Separate tasks, parallel |
| Cancellation | Parent cancelled → children dropped | Independent lifecycle |
| `'static` requirement | No | Yes |
| Overhead | Lower | Task spawn cost |

**Prefer `join!`** unless you need parallelism across cores or `'static` is acceptable.

## Channels vs Shared State

### The Actor Pattern

An actor owns its state in a task and receives `mpsc` messages; each message carries a `oneshot::Sender` for its reply. The public handle is a cheap `Clone` wrapper over the `mpsc::Sender`.

```rust
enum ActorMessage {
    GetUniqueId { respond_to: oneshot::Sender<u32> },
}

async fn run_actor(mut rx: mpsc::Receiver<ActorMessage>) {
    while let Some(msg) = rx.recv().await {
        // handle msg, reply through its respond_to
    }
}
```

### When to Use Channels

- Isolating concerns (network IO vs business logic)
- Exclusive resource access (database connections, file handles)
- Natural message-passing domains (chat, events)
- Graceful shutdown (channel closure signals termination)

### When to Use Shared State

- Short-lived, infrequent access
- Read-heavy workloads (`RwLock`)
- Simple counters/flags (`AtomicUsize`)

### Deadlock Warning

Bounded channels can deadlock if they form a cycle. Break the cycle with `try_send` on one link, a `oneshot` for responses (always returns immediately), or an unbounded channel where appropriate.

## spawn vs spawn_blocking

| Scenario | Solution |
|----------|----------|
| Blocking IO (filesystem, diesel) | `spawn_blocking` |
| CPU-bound, few tasks | `spawn_blocking` |
| CPU-bound, many tasks | `rayon` |
| Runs forever | `std::thread::spawn` |

**`spawn_blocking` tasks cannot be aborted once started** — they run to completion even if `abort()` is called.

Bridge CPU-bound `rayon` work back into async over a `oneshot`:

```rust
let (send, recv) = tokio::sync::oneshot::channel();
rayon::spawn(move || {
    let sum: i32 = nums.par_iter().sum();
    let _ = send.send(sum);
});
recv.await.expect("rayon task panicked")
```

## Mutex Comparison

Choosing the wrong mutex is a common source of bugs. See also `send-sync.md` for trait bound details.

| Mutex | Use When |
|-------|----------|
| `std::sync::Mutex` | Lock held briefly, no `.await` while locked |
| `tokio::sync::Mutex` | Must hold lock across `.await` points |
| `RobustMutex` (cancel-safe-futures) | Need cancellation safety in `select!` |

### std::sync::Mutex (Default Choice)

**Two distinct problems in async:**

1. **Blocking the executor** — a contended lock blocks the thread, starving the runtime, even for brief contention.
2. **Holding across `.await` deadlocks** — the task holding the lock may need to resume on the very thread that's blocked waiting for it. (`std::sync::MutexGuard` is also `!Send`, so this usually fails to compile under a multi-threaded runtime.)

```rust
use std::sync::Mutex;

// ❌ BAD - guard held across await: deadlock risk, and the future is !Send
async fn bad(mutex: &Mutex<i32>) {
    let mut guard = mutex.lock().unwrap();
    *guard += 1;
    do_async_work().await;  // guard still held across .await
}

// ✅ GOOD - copy/clone what you need, drop the guard, then await
async fn good(mutex: &Mutex<i32>) {
    let value = {
        let mut guard = mutex.lock().unwrap();
        *guard += 1;
        *guard
    };  // guard dropped here
    do_async_work_with(value).await;
}
```

**Use when:** lock held briefly, contention rare, no `.await` while locked — faster than `tokio::sync::Mutex` when uncontended.

### tokio::sync::Mutex (For Holding Across .await)

```rust
use tokio::sync::Mutex;

async fn with_lock(mutex: &Mutex<i32>) {
    let mut guard = mutex.lock().await;
    *guard += 1;
    do_async_work().await;  // OK with tokio Mutex
}
```

**Use when:** you genuinely need to hold the lock across `.await`. **Avoid when:** quick synchronous access—`std::sync::Mutex` is faster.

### RobustMutex (Cancellation-Safe)

Standard mutexes lose queue position if cancelled in `select!`. `RobustMutex` from `cancel-safe-futures` handles this:

```rust
use cancel_safe_futures::sync::RobustMutex;

let mutex = RobustMutex::new(data);

// Safe to use in select! - won't lose queue position
tokio::select! {
    guard = mutex.lock() => { /* use guard */ }
    _ = shutdown.recv() => { /* cancelled, but queue position preserved */ }
}
```

## Timeouts

Bound any async operation with `tokio::time::timeout`; a timeout returns `Err`:

```rust
match tokio::time::timeout(Duration::from_secs(5), fetch_data()).await {
    Ok(result) => handle(result?),
    Err(_) => handle_timeout(),
}
```

## Graceful Shutdown with CancellationToken

`CancellationToken` from `tokio-util` is the standard pattern:

```rust
use tokio_util::sync::CancellationToken;

let token = CancellationToken::new();
let cloned = token.clone();

tokio::spawn(async move {
    loop {
        tokio::select! {
            _ = cloned.cancelled() => {
                println!("Shutting down");
                break;
            }
            _ = do_work() => {}
        }
    }
});

// Later: trigger shutdown
token.cancel();
```

**Child tokens:** Use `token.child_token()` for hierarchical cancellation.

## Async Traits

### Native async fn in traits (Rust 1.75+)

```rust
trait MyTrait {
    async fn process(&self) -> Result<(), Error>;
}
```

### Limitation: No `dyn Trait` Support

Native async traits don't support dynamic dispatch. Workarounds:
- `async-trait` crate - Still needed for `dyn` dispatch
- `trait-variant` crate - Generate Send/non-Send variants

### Send Bounds

Native async traits don't automatically add `Send`. For multi-threaded runtimes:

```rust
trait MyTrait {
    fn process(&self) -> impl Future<Output = ()> + Send;
}
```

## STOP and Reconsider

**Before spawning a task without tracking the `JoinHandle`:** Untracked tasks are fire-and-forget — you lose errors, can't cancel them, and can't wait for them during shutdown. Use `JoinSet` or `TaskTracker` to manage task lifecycles.

```rust
// ❌ BAD - fire and forget
tokio::spawn(async { do_work().await });

// ✅ GOOD - tracked
let mut set = JoinSet::new();
set.spawn(async { do_work().await });
// Later: collect results and handle errors
while let Some(result) = set.join_next().await {
    result??;
}
```

**Before using an unbounded channel:** Unbounded channels provide no backpressure. A slow consumer with a fast producer will consume unlimited memory. Use bounded channels with explicit capacity, and handle the `SendError` when the channel is full.

## Resources

- Alice Ryhl's Blog: https://ryhl.io/
- Tokio Documentation: https://docs.rs/tokio
- Tokio Tutorial: https://tokio.rs/tokio/tutorial
- cancel-safe-futures: https://docs.rs/cancel-safe-futures
- tokio-util: https://docs.rs/tokio-util
