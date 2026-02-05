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
    let idx = res.unwrap();
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

```rust
struct MyActor {
    receiver: mpsc::Receiver<ActorMessage>,
    next_id: u32,
}

#[derive(Clone)]
pub struct MyActorHandle {
    sender: mpsc::Sender<ActorMessage>,
}

enum ActorMessage {
    GetUniqueId { respond_to: oneshot::Sender<u32> },
}

async fn run_my_actor(mut actor: MyActor) {
    while let Some(msg) = actor.receiver.recv().await {
        actor.handle_message(msg);
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

Bounded channels can deadlock if they form a cycle. Solutions:
- Use `try_send` for one link in the cycle
- Use `oneshot` for responses (always returns immediately)
- Break cycles with unbounded channels where appropriate

## spawn vs spawn_blocking

| Scenario | Solution |
|----------|----------|
| Blocking IO (filesystem, diesel) | `spawn_blocking` |
| CPU-bound, few tasks | `spawn_blocking` |
| CPU-bound, many tasks | `rayon` |
| Runs forever | `std::thread::spawn` |

### spawn_blocking Caveats

```rust
// spawn_blocking tasks CANNOT be aborted once started
let handle = tokio::task::spawn_blocking(|| {
    expensive_computation()  // Runs to completion even if abort() called
});
```

### Rayon Integration

```rust
async fn parallel_sum(nums: Vec<i32>) -> i32 {
    let (send, recv) = tokio::sync::oneshot::channel();

    rayon::spawn(move || {
        let sum = nums.par_iter().sum();
        let _ = send.send(sum);
    });

    recv.await.expect("Panic in rayon::spawn")
}
```

## Mutex Comparison

Choosing the wrong mutex is a common source of bugs. See also `send-sync.md` for trait bound details.

| Mutex | Use When |
|-------|----------|
| `std::sync::Mutex` | Lock held briefly, no `.await` while locked |
| `tokio::sync::Mutex` | Must hold lock across `.await` points |
| `RobustMutex` (cancel-safe-futures) | Need cancellation safety in `select!` |

### std::sync::Mutex (Default Choice)

```rust
use std::sync::Mutex;

// ✅ GOOD - lock released before await
async fn good(mutex: &Mutex<i32>) {
    {
        let mut guard = mutex.lock().unwrap();
        *guard += 1;
    }  // Released here
    do_async_work().await;
}
```

**Two distinct problems with std::sync::Mutex in async:**

1. **Blocking the executor** - If the lock is contended, the thread blocks waiting, starving the async runtime. This happens even for brief contention.

2. **Holding across `.await` causes deadlocks** - The task holding the lock might need to resume on the same thread that's blocked waiting for the lock.

```rust
// ❌ BAD - Problem 1: blocks executor thread if contended
async fn blocks_executor(mutex: &Mutex<i32>) {
    let guard = mutex.lock().unwrap();  // Thread blocks here!
    // Even if released immediately, contention starves runtime
}

// ❌ BAD - Problem 2: potential deadlock
async fn potential_deadlock(mutex: &Mutex<i32>) {
    let guard = mutex.lock().unwrap();
    do_async_work().await;  // Task suspended while holding lock
    // If runtime tries to resume this on a thread waiting for this lock: deadlock
}
```

**Advantages:** Faster when uncontended, no async overhead.
**Use when:** Lock is held briefly, contention is rare, no `.await` while locked.

### tokio::sync::Mutex (For Holding Across .await)

```rust
use tokio::sync::Mutex;

// ✅ Now allowed - guard can be held across await
async fn with_lock(mutex: &Mutex<i32>) {
    let mut guard = mutex.lock().await;
    *guard += 1;
    do_async_work().await;  // OK with tokio Mutex
}
```

**Use when:** You genuinely need to hold the lock across `.await` points.
**Avoid when:** Quick synchronous access—`std::sync::Mutex` is faster.

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

Use `tokio::time::timeout` to bound async operations:

```rust
use tokio::time::{timeout, Duration};

match timeout(Duration::from_secs(5), fetch_data()).await {
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

**Before holding a `MutexGuard` across `.await`:** Restructure your code. Clone the data you need, drop the guard, then await. If you genuinely need to hold the lock across an async boundary, use `tokio::sync::Mutex` — but first ask if the design is right.

```rust
// ❌ BAD - MutexGuard held across await
let guard = mutex.lock().unwrap();
let value = guard.clone();
do_something(value).await; // guard still held!
drop(guard);

// ✅ GOOD - clone and drop before await
let value = {
    let guard = mutex.lock().unwrap();
    guard.clone()
}; // guard dropped here
do_something(value).await;
```

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

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `read_exact` in `select!` | Use `read` + manual buffering |
| Blocking >100μs without `.await` | Use `spawn_blocking` or `rayon` |
| Spawning forever-running task on `spawn_blocking` | Use `std::thread::spawn` |
| Expecting `dyn AsyncTrait` to work | Use `async-trait` crate |
| Bounded channel cycles | Use `try_send` or `oneshot` for responses |
| Using `std::sync::Mutex` across `.await` | Use `tokio::sync::Mutex` or scope the guard |
| Mutex in `select!` losing queue position | Use `RobustMutex` from cancel-safe-futures |
| No timeout on network operations | Wrap with `tokio::time::timeout` |
| Manual shutdown flags with `AtomicBool` | Use `CancellationToken` from tokio-util |

## Resources

- Alice Ryhl's Blog: https://ryhl.io/
- Tokio Documentation: https://docs.rs/tokio
- Tokio Tutorial: https://tokio.rs/tokio/tutorial
- cancel-safe-futures: https://docs.rs/cancel-safe-futures
- tokio-util: https://docs.rs/tokio-util
