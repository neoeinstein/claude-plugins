# Functional Core, Imperative Shell in Rust

## When to Use This Reference

- Organizing modules in a new crate or project
- Deciding where business logic vs I/O code lives
- Refactoring tangled code that mixes logic and side effects
- Designing for testability without excessive mocking

## Quick Reference

| Module Type | Contains | Depends On | Testable With |
|-------------|----------|------------|---------------|
| Domain (pure) | Types, validation, business rules, transformations | Other domain modules only | Unit tests, property tests |
| Service (I/O) | Database calls, HTTP clients, file I/O, external APIs | Domain modules + external crates | Integration tests, mocks |
| Orchestration | Wiring services together, request handling | Domain + Service modules | Integration tests |

## The Rule

**Separate pure logic from I/O.** Domain logic should be pure functions that take data in and return data out. I/O operations should happen at the edges, orchestrated by thin service layers.

**The boundary is visible in type signatures.** If a function returns `impl Future`, takes `&dyn Database`, or requires `&self` with I/O state, it belongs in the imperative shell. If it takes values and returns values, it belongs in the functional core.

## Module Organization

### The Pattern

```
src/
├── domain/           # Functional Core — pure logic
│   ├── mod.rs
│   ├── types.rs      # Domain types, newtypes, enums
│   ├── validation.rs # Validation rules (all pure functions)
│   └── rules.rs      # Business rules, transformations
├── service/          # Imperative Shell — I/O boundary
│   ├── mod.rs
│   ├── database.rs   # Database operations
│   └── external.rs   # External API calls
├── handler/          # Orchestration — wires core + shell
│   ├── mod.rs
│   └── routes.rs     # HTTP handlers, CLI commands
└── lib.rs
```

### Identifying the Boundary

**In the functional core (domain):**
- Type definitions and newtypes
- Validation logic: `fn validate(input: &Input) -> Result<Validated, ValidationError>`
- Business rules: `fn calculate_price(items: &[Item], discount: Discount) -> Price`
- Data transformations: `fn to_response(entity: &Entity) -> Response`

**In the imperative shell (service):**
- Database queries: `async fn find_user(db: &Pool, id: UserId) -> Result<User>`
- HTTP calls: `async fn fetch_weather(client: &Client, city: &str) -> Result<Weather>`
- File operations: `fn read_config(path: &Path) -> Result<Config>`

**In the orchestration layer (handler):**
- Gather inputs from the shell
- Pass to the core for processing
- Persist results through the shell

### The Gather-Process-Persist Pattern

```rust
// handler/routes.rs — orchestration
async fn handle_order(
    db: &Pool,
    request: OrderRequest,
) -> Result<OrderResponse, AppError> {
    // 1. GATHER: fetch data from I/O boundary
    let user = service::database::find_user(db, &request.user_id).await?;
    let items = service::database::find_items(db, &request.item_ids).await?;

    // 2. PROCESS: pure domain logic (no I/O, no async)
    let validated = domain::validation::validate_order(&user, &items)?;
    let order = domain::rules::create_order(validated);
    let response = domain::types::OrderResponse::from(&order);

    // 3. PERSIST: write results through I/O boundary
    service::database::save_order(db, &order).await?;

    Ok(response)
}
```

The `domain::` calls are all pure — easily unit-tested without mocking.
The `service::` calls handle I/O — tested with integration tests or mock databases.

## Why This Matters in Rust

Rust's type system makes FCIS particularly effective:

- **No hidden side effects:** Unlike languages with implicit I/O, Rust's async and borrowing make I/O visible in function signatures.
- **Ownership enforces boundaries:** Pure functions take `&T` or owned values — they can't mutate external state.
- **Testability without mocks:** Pure domain logic needs only unit tests with concrete data. No trait objects, no mock frameworks.
- **Compile-time boundary enforcement:** A domain module that doesn't import `tokio`, `sqlx`, or `reqwest` is provably pure.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Putting database calls in domain logic | Extract I/O to service modules, pass data to domain functions |
| Making everything async "just in case" | Only async at the I/O boundary. Domain logic is sync. |
| Testing domain logic with mocked databases | If you need mocks, the logic isn't pure enough. Refactor. |
| Mixing validation with persistence | Validate first (pure), then persist (I/O). Separate steps. |
| Giant handler functions doing everything | Split into gather, process, persist. Each step is clear. |

## Resources

- Gary Bernhardt's "Boundaries" talk: https://www.destroyallsoftware.com/talks/boundaries
- Rust Design Patterns: https://rust-unofficial.github.io/patterns/
