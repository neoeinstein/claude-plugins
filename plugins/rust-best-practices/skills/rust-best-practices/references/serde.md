# Serde Serialization Patterns

## When to Use This Reference

- Configuring derive attributes (`rename_all`, `skip_serializing_if`)
- Choosing enum representations (tagged, untagged)
- Writing custom serialization
- Optimizing for performance (zero-copy)
- Handling unknown fields

## Quick Reference

| Goal | Attribute |
|------|-----------|
| Rename all fields | `#[serde(rename_all = "camelCase")]` |
| Accept multiple names | `#[serde(alias = "other_name")]` |
| Omit None on output | `#[serde(skip_serializing_if = "Option::is_none")]` |
| Handle missing key on input | `#[serde(default)]` — **required** if key may be absent |
| Symmetric optional field | Both: `#[serde(default, skip_serializing_if = "Option::is_none")]` |
| Three-state (missing/null/present) | `optional_field::Field<T>` + `#[serde_optional_fields]` |
| Validate on deserialize | `#[serde(try_from = "RawType")]` |
| Internally tagged enum | `#[serde(tag = "type")]` |
| Reject unknown fields | `#[serde(deny_unknown_fields)]` |
| Override trait bounds | `#[serde(bound = "T: MyTrait")]` |
| Zero-copy string | `&'a str` field |
| Zero-copy with fallback | `Cow<'a, str>` with `#[serde(borrow)]` |

## `null` vs Missing Keys

**`serde_json` does NOT treat `null` and a missing key as equivalent.** They are different code paths with different behavior guarantees.

| JSON input | serde_json code path | Result for `Option<T>` |
|------------|---------------------|------------------------|
| `"field": null` | `Deserializer::deserialize_option()` → `visit_none()` | `None` |
| `"field": value` | `Deserializer::deserialize_option()` → `visit_some()` | `Some(value)` |
| key absent | Derive macro's `deserialize_missing_field()` | **depends on attributes** |

When a key is missing entirely, the serde **derive macro** (not `serde_json`) decides what happens. For `Option<T>` fields, the derive macro has special handling that *may* produce `None`, but this is an implicit derive feature — not a `serde_json` guarantee.

### Always Use `#[serde(default)]` for Optional Wire Fields

If a key may be absent from the JSON, **always annotate with `#[serde(default)]`**. This makes the intent explicit and doesn't rely on implicit derive behavior:

```rust
// GOOD: explicit about handling missing keys
#[derive(Deserialize)]
struct ApiResponse {
    #[serde(default)]
    user: Option<FoundUser>,  // Key may be absent, null, or present

    #[serde(default)]
    metadata: Option<Metadata>,  // Key may be absent
}

// BAD: relies on implicit derive behavior for missing keys
#[derive(Deserialize)]
struct ApiResponse {
    user: Option<FoundUser>,  // Handles null, but missing key behavior is implicit
}
```

### Generic Struct Gotcha

`#[serde(default)]` on `Option<T>` where `T` is a **type parameter** adds `T: Default` to the derived bounds — even though `Option<T>` is always `Default`. This is a serde derive limitation.

```rust
// This compiles:
#[derive(Deserialize)]
struct Wrapper {
    #[serde(default)]
    data: Option<ConcreteType>,  // ConcreteType doesn't need Default
}

// This adds T: Default bound:
#[derive(Deserialize)]
struct Wrapper<T> {
    #[serde(default)]
    data: Option<T>,  // Now requires T: Default even though Option<T> is always Default
}
```

For generic structs, either omit `#[serde(default)]` on the generic fields (relying on derive behavior for `Option<T>`), or use `#[serde(bound = "...")]` to override the generated bounds.

### STOP — Anti-Rationalization

| Rationalization | Reality |
|-----------------|---------|
| "`Option<T>` handles missing fields automatically" | **It doesn't.** `null` → `None` is serde_json. Missing key → `None` is the derive macro. These are separate mechanisms. Be explicit with `#[serde(default)]`. |
| "null and missing are the same thing" | **They are not.** Different code paths in the deserializer. `null` goes through `deserialize_option()`. Missing goes through `deserialize_missing_field()`. Don't conflate them. |
| "`#[serde(default)]` is redundant on `Option<T>`" | It's not redundant — it makes the contract explicit. Implicit behavior can change or surprise. Explicit `#[serde(default)]` documents that the key may be absent. |
| "The tests pass without `#[serde(default)]`" | Your test data probably includes the key. Real-world APIs omit keys. Write tests for missing keys, or just add the attribute. |

### Serialization: Pair `#[serde(default)]` with `skip_serializing_if`

The deserialization and serialization sides are mirrors. If a field can be absent on input, it should also be omittable on output. Always pair `#[serde(default)]` with `#[serde(skip_serializing_if = "Option::is_none")]`:

```rust
#[derive(Serialize, Deserialize)]
struct ApiResponse {
    id: String,

    // GOOD: symmetric — absent on input, omitted on output
    #[serde(default, skip_serializing_if = "Option::is_none")]
    metadata: Option<Metadata>,

    // BAD: asymmetric — absent on input, but serializes as "metadata": null
    #[serde(default)]
    metadata: Option<Metadata>,
}
```

Without `skip_serializing_if`, serializing an `Option::None` produces `"field": null` in the output. This is usually undesirable — it inflates payloads, confuses consumers that distinguish null from absent, and makes PATCH semantics ambiguous.

### Three-State Fields: Missing vs Null vs Present

Sometimes you need to distinguish all three states — the field was absent (don't touch it), explicitly `null` (clear it), or has a value (set it). `Option<T>` collapses absent and null into `None`, losing this distinction.

Use the `optional_field` crate's `Field<T>` for three-state semantics:

```rust
use optional_field::Field;

// Manual annotation — correct but repetitive:
#[derive(Serialize, Deserialize)]
struct EventPatch {
    #[serde(default, skip_serializing_if = "Field::is_missing")]
    enabled: Field<bool>,

    #[serde(default, skip_serializing_if = "Field::is_missing")]
    description: Field<String>,
}

// Better — `serde_optional_fields` adds the attributes automatically:
use optional_field::serde_optional_fields;

#[serde_optional_fields]
#[derive(Serialize, Deserialize)]
struct EventPatch {
    enabled: Field<bool>,              // Missing = don't change, Some = set, None = clear
    description: Field<String>,
}
```

The `#[serde_optional_fields]` macro scans the struct for `Field<T>` fields and automatically adds `#[serde(default, skip_serializing_if = "Field::is_missing")]` to each one. Use it to avoid the per-field boilerplate.

| Wire input | `Field<T>` value | Semantic meaning |
|------------|-----------------|------------------|
| key absent | `Field::Missing` | Don't touch this field |
| `"field": null` | `Field::Present(None)` | Explicitly clear/unset |
| `"field": value` | `Field::Present(Some(v))` | Set to new value |

This is essential for **PATCH endpoints** — `Option<T>` can't distinguish "the client didn't send this field" from "the client wants to null it out." `Field<T>` makes that distinction at the type level.

## Common Attributes

### Container Level

```rust
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]  // snake_case, PascalCase, kebab-case
#[serde(deny_unknown_fields)]        // Reject unexpected fields
#[serde(default)]                    // Use Default for all missing fields
struct Config { /* ... */ }
```

### Field Level

```rust
#[derive(Serialize, Deserialize)]
struct User {
    #[serde(rename = "type")]  // Handle reserved keywords
    user_type: String,

    #[serde(alias = "user_name", alias = "username")]  // Accept multiple names
    name: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    nickname: Option<String>,

    #[serde(default = "default_timeout")]
    timeout_ms: u64,

    #[serde(skip)]  // Skip both serialization and deserialization
    internal: String,
}

fn default_timeout() -> u64 { 5000 }
```

## Enum Representations

| Style | Attribute | JSON |
|-------|-----------|------|
| Externally tagged | (default) | `{"Request": {...}}` |
| Internally tagged | `tag = "type"` | `{"type": "Request", ...}` |
| Adjacently tagged | `tag = "t", content = "c"` | `{"t": "Request", "c": {...}}` |
| Untagged | `untagged` | `{...}` |

```rust
// Internally tagged (common for REST APIs)
#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]
enum Event {
    Click { x: i32, y: i32 },
    KeyPress { key: String },
}
// {"type": "Click", "x": 10, "y": 20}

// Untagged - tries variants in order
#[derive(Deserialize)]
#[serde(untagged)]
enum Value {
    Specific { id: u64, name: String },  // Try first
    Generic(serde_json::Value),           // Fallback
}
```

**Notes:**
- Internally tagged doesn't support tuple variants
- Untagged has performance cost—tries all variants
- Only externally tagged works in no-alloc environments

## Custom Serialization

### Field-Level with `serialize_with`

```rust
#[derive(Serialize, Deserialize)]
struct Record {
    #[serde(serialize_with = "serialize_ts", deserialize_with = "deserialize_ts")]
    timestamp: DateTime<Utc>,
}

fn serialize_ts<S>(dt: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error>
where S: Serializer {
    s.serialize_i64(dt.timestamp())
}
```

### Using `serde_with` Crate (Recommended)

```rust
use serde_with::{serde_as, DisplayFromStr, NoneAsEmptyString};

#[serde_as]
#[derive(Serialize, Deserialize)]
struct Config {
    #[serde_as(as = "DisplayFromStr")]
    port: u16,  // Serializes as "8080"

    #[serde_as(as = "NoneAsEmptyString")]
    nickname: Option<String>,  // "" becomes None
}
```

Useful `serde_with` helpers:
- `DisplayFromStr` - Use `Display`/`FromStr`
- `NoneAsEmptyString` - Empty string ↔ None
- `DefaultOnError` - Default on parse failure
- `OneOrMany` - Accept single or array

## Validation with try_from

Use `#[serde(try_from = "Type")]` for fallible conversion with validation:

```rust
#[derive(Deserialize)]
#[serde(try_from = "String")]
struct Email(String);

impl TryFrom<String> for Email {
    type Error = &'static str;

    fn try_from(s: String) -> Result<Self, Self::Error> {
        if s.contains('@') {
            Ok(Email(s))
        } else {
            Err("invalid email: missing @")
        }
    }
}

// Deserialization now validates automatically
let email: Email = serde_json::from_str(r#""user@example.com""#)?;
```

For serialization, use `#[serde(into = "Type")]` with `Into<Type>` impl.

## Generic Types with Custom Bounds

Override derived trait bounds with `#[serde(bound = "...")]`:

```rust
#[derive(Serialize, Deserialize)]
#[serde(bound = "T: Serialize + DeserializeOwned + Default")]
struct Wrapper<T> {
    #[serde(default)]
    value: T,
}
```

Use when:
- Default bounds are too restrictive or too permissive
- Generic type has complex trait requirements
- You need `DeserializeOwned` instead of `Deserialize<'de>`

## Zero-Copy Deserialization

Borrow directly from input to avoid allocations:

```rust
#[derive(Deserialize)]
struct User<'a> {
    id: u32,
    name: &'a str,  // Borrows from input
}

let input = r#"{"id": 1, "name": "Alice"}"#;
let user: User = serde_json::from_str(input)?;
// user.name points into input
```

### Using `Cow` for Flexibility

```rust
use std::borrow::Cow;

#[derive(Deserialize)]
struct Document<'a> {
    #[serde(borrow)]
    title: Cow<'a, str>,  // Borrows when possible, owns when escaped
}
```

`Cow` borrows when possible but falls back to owned when transformation needed (e.g., escape sequences).

### Trait Bounds

- `Deserialize<'de>` - Can borrow from input
- `DeserializeOwned` - Owns all data (for IO streams)

## Flatten and deny_unknown_fields

### Flatten Common Fields

```rust
#[derive(Serialize, Deserialize)]
struct Pagination { limit: u64, offset: u64 }

#[derive(Serialize, Deserialize)]
struct UserList {
    users: Vec<User>,
    #[serde(flatten)]
    pagination: Pagination,
}
// {"users": [...], "limit": 10, "offset": 0}
```

### Capture Unknown Fields

```rust
#[derive(Serialize, Deserialize)]
struct Event {
    event_type: String,
    #[serde(flatten)]
    extra: HashMap<String, Value>,  // Catches all others
}
```

### ⚠️ Incompatibility

**`flatten` and `deny_unknown_fields` cannot be used together** - neither on outer struct nor flattened inner struct.

## Performance Tips

| Pattern | Benefit |
|---------|---------|
| `&str` / `&[u8]` fields | Zero-copy |
| `Cow<str>` with `#[serde(borrow)]` | Zero-copy when possible |
| `skip_serializing_if` | Smaller output |
| Avoid `flatten` in hot paths | Has overhead |
| Prefer tagged over untagged | Untagged tries all variants |
| `from_slice` over `from_reader` | Avoids buffering |

## Attribute Cheat Sheet

```rust
// Container
#[serde(rename_all = "camelCase")]
#[serde(deny_unknown_fields)]
#[serde(default)]
#[serde(tag = "type")]
#[serde(tag = "t", content = "c")]
#[serde(untagged)]
#[serde(transparent)]  // Newtype wrapper
#[serde(from = "Type", into = "Type")]  // Infallible convert
#[serde(try_from = "Type")]  // Fallible convert (validation)
#[serde(bound = "T: Trait")]  // Override trait bounds

// Field
#[serde(rename = "name")]
#[serde(alias = "other_name")]  // Accept multiple names
#[serde(default)]
#[serde(default = "fn_path")]
#[serde(skip)]
#[serde(skip_serializing_if = "predicate")]
#[serde(serialize_with = "fn", deserialize_with = "fn")]
#[serde(with = "module")]
#[serde(borrow)]
#[serde(flatten)]
```

## Dead Fields and Underscore-Prefix Trap

**Delete unused fields from `Deserialize` structs.** Serde ignores fields the struct doesn't declare — keeping unread fields creates coupling, not safety. If the source renames a column you never read, your code breaks for nothing.

```rust
// GOOD: only declare what you read
/// SQL: SELECT id, username, password_hash FROM users WHERE username = ?
#[derive(Deserialize)]
struct UserRow {
    id: String,
    password_hash: String,
}

// BAD: dead weight coupling to unread columns
#[derive(Deserialize)]
struct UserRow {
    id: String,
    #[expect(dead_code, reason = "deserialized but not used")]
    username: String,
    password_hash: String,
}
```

**Never prefix Serde fields with `_` to suppress `dead_code`.** Serde derives the key name from the identifier — `_field` expects `"_field"` in the JSON/SQL, not `"field"`. This silently breaks deserialization at runtime.

The only legitimate `#[expect(dead_code)]` on DTO-adjacent structs is for **structural requirements** — macro-required fields or typed struct APIs. See `references/dead-code-in-serde-structs.md` for the full decision framework.

## Resources

- Serde Documentation: https://serde.rs
- serde_with Crate: https://docs.rs/serde_with
- Serde Attributes: https://serde.rs/attributes.html
