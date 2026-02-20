# Dead Code in Serde Structs

## When to Use This Reference

- Seeing `dead_code` warnings on `#[derive(Deserialize)]` struct fields
- Tempted to add `#[expect(dead_code)]` or underscore-prefix to a DTO field
- Reviewing lint suppressions on structs that represent SQL results, JSON responses, or API payloads
- Deciding whether a `Deserialize` field should be kept, deleted, or annotated

## The Core Insight

Serde's default behavior **ignores unknown fields** during deserialization. If your source (JSON, SQL result, etc.) contains a field that your struct doesn't declare, serde silently skips it. Deserialization only fails when:

- Your struct declares a field the source **doesn't provide** (missing required field)
- A field's **type doesn't match** the source value

This means: **not reading a field cannot break deserialization.** Keeping unused fields on a `Deserialize` struct is not a safety measure. It's a liability -- it couples you to schema details you don't depend on. If the source renames or removes a column you never read, your deserialization breaks for no reason.

## The Rule

**Delete unused fields from `Deserialize` structs.** Add a comment documenting the full source shape instead.

```rust
// GOOD: only declare what you read, comment the rest
/// SQL: SELECT id, username, password_hash FROM users WHERE username = ?
/// Only `id` and `password_hash` are consumed; `username` is the lookup key.
#[derive(Deserialize)]
struct UserRow {
    id: String,
    password_hash: String,
}

// BAD: carrying dead weight and coupling to unread columns
#[derive(Deserialize)]
struct UserRow {
    id: String,
    #[expect(dead_code, reason = "deserialized from D1 query but not used")]
    username: String,
    password_hash: String,
}
```

## STOP -- Anti-Rationalization

| Rationalization | Reality |
|-----------------|---------|
| "The field must match the SQL/JSON schema" | No. Serde ignores fields not present in your struct. You only need to declare fields you read. |
| "I'll use it later" | Delete it now. Adding a field back is trivial. Carrying dead fields is a maintenance cost and a coupling risk. |
| "It documents the response shape" | Use a comment instead. Comments document without creating coupling. |
| "Removing it might break deserialization" | The opposite: *having* it can break deserialization. If the source renames a column you don't read, your code breaks for nothing. Fewer fields = fewer ways to break. |
| "It's just one `#[expect(dead_code)]`, not a big deal" | It normalizes the pattern. Every dead DTO field you keep teaches the next reader that dead DTO fields are fine. They aren't. |
| "I'll prefix it with `_` to suppress the warning" | **Never do this with Serde.** `_field` changes the expected key name. Serde will look for `"_field"` in the JSON/SQL, not `"field"`. This silently breaks deserialization. |

## Never Underscore-Prefix Serde Fields

Serde derives the expected field name from the Rust identifier. Prefixing with `_` changes the contract:

```rust
#[derive(Deserialize)]
struct Row {
    _username: String,  // Serde expects "_username" in JSON, not "username"
}
```

This applies regardless of `rename_all`. If you use `#[serde(rename_all = "camelCase")]`, a field named `_user_name` maps to `"_userName"`, not `"userName"`.

The underscore-prefix trick that works for regular Rust dead code **does not work for Serde**. It silently changes the deserialization contract and will cause runtime failures.

## What To Do Instead

### For SQL / database query results

Delete the field. Add a doc comment showing the full query and noting which columns aren't consumed.

```rust
/// Query: `SELECT e.id, e.source, e.title, e.status, w.header_json FROM ...`
/// Only `header_json` is consumed; remaining columns are for the query's
/// join/filter logic.
#[derive(Deserialize)]
struct EventListRow {
    header_json: Option<String>,
}
```

### For external API responses

Delete the field. Reference the API docs or the DTO source file.

```rust
/// Partial deserialization of the /users endpoint response.
/// See `api_types::FullUserResponse` for the complete schema.
#[derive(Deserialize)]
struct UserSummary {
    id: String,
    display_name: String,
    // Response also includes: email, avatar_url, created_at, settings
}
```

### For fields you might need soon

Delete them anyway. Re-adding a field when you need it is a one-line change with a test to prove it works. Carrying dead fields until "someday" creates real cost now for speculative benefit later.

## When `dead_code` on DTO-Adjacent Structs IS Legitimate

These are the **only** cases where `#[expect(dead_code)]` is correct on a struct used with deserialization or framework macros:

### Macro-required fields

Some macros require specific fields to exist in the struct, even if your code never reads them.

```rust
// The #[durable_object] macro requires `env: Env` in the struct.
// DO method handlers receive env through their context parameter.
#[durable_object]
pub struct MyDurableObject {
    state: State,
    #[expect(dead_code, reason = "#[durable_object] macro requires env field")]
    env: Env,
}
```

### Typed struct requirements

Some APIs require a typed struct even when you only care about the container, not the field value.

```rust
// D1's .first::<T>() requires a typed struct; we only check Some vs None.
#[derive(Deserialize)]
struct ExistsRow {
    #[expect(dead_code, reason = "D1 .first::<T>() requires typed struct; only Option<ExistsRow> is checked")]
    row_exists: i32,
}
```

These are **structural requirements** -- the field must exist for the code to compile or the framework to function. They are not "the data might be useful."

## Relationship to `deny_unknown_fields`

If a struct uses `#[serde(deny_unknown_fields)]`, then the struct **must** declare every field the source provides. In that case, carrying unused fields is required. But `deny_unknown_fields` is opt-in and rarely appropriate for DTOs receiving external data (it makes your code brittle to upstream additions). If you find yourself adding dead fields to satisfy `deny_unknown_fields`, question whether `deny_unknown_fields` is correct for that struct.

## Checklist for Reviewing `dead_code` on Serde Structs

1. Is this a `#[derive(Deserialize)]` struct? If yes, you almost certainly **do not need** the dead field. Delete it.
2. Is the field required by a macro or framework constraint? If yes, `#[expect(dead_code, reason = "...")]` is correct. Document the constraint.
3. Does the struct use `#[serde(deny_unknown_fields)]`? If yes, the field may be required. But also question whether `deny_unknown_fields` is appropriate.
4. Is someone proposing to prefix the field with `_`? **Hard no.** This changes the serde contract.
5. Is the reason "documents the schema"? Use a comment instead. Comments don't create coupling.
