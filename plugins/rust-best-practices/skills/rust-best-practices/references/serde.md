# Serde Serialization Patterns

## Choosing a serialization stack: serde vs facet

serde and facet each anchor a whole ecosystem. Pick one as the default; bridge at boundaries.

| Concern | serde stack | facet stack |
|---|---|---|
| Serialize | `serde` + `serde_json` / `serde_*` | `facet` + `facet-json` / `facet-csv` |
| Errors | `thiserror` + `miette` | `facet-error` |
| CLI / config | `clap` / `figment` | `figue` |
| String newtypes | `aliri_braid` | `strid` braids |
| Test / diff | `assert_eq!` / `insta` | `rediff` |
| Validation | `validator` / manual | `facet-validate` |

**serde** — the mature default: largest ecosystem, faster (monomorphizes per type×format, so it wins hot loops), and what public APIs and serde-demanding dependencies expect. **facet** — one `#[derive(Facet)]` powers many formats (JSON, CSV, pretty-print, diff, CLI) with span-aware parse errors; younger and slower in hot loops. Both derives can coexist on one type; prefer bridging via `From`/`TryFrom` at crate boundaries over dual-deriving domain types.

Deep facet guidance (attributes, Decimal/money patterns, gotchas) lives in the separate `facet` skill, which loads on its own triggers.

## When to Use This Reference

- Configuring derive attributes (`rename_all`, `skip_serializing_if`)
- Choosing enum representations (tagged, untagged)
- Writing custom serialization
- Optimizing for performance (zero-copy)
- Handling unknown fields
- Constructing outgoing payloads you own (requests, events, messages)

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

## Constructing Output: Typed Structs, Not `json!`

Most of this doc is about *reading* data you don't control. This section is about *writing* data you **do** control — request bodies, event payloads, message-bus messages, API responses.

**`serde_json::json!` (and hand-built `serde_json::Value`) is almost always the wrong tool for data you own.** It trades away every guarantee the type system gives you for a bag of magic-string keys:

- No field is checked. A typo'd key (`"mached"`) or a wrong-typed value compiles and ships.
- The shape lives at the call site, not in a type. Nothing links "this payload" to "the topic/endpoint/kind it belongs to," so one producer can emit three incompatible shapes and nothing complains.
- Consumers can't share a `#[derive(Deserialize)]` type — the contract is untyped on both ends.

Reserve `json!` for genuinely dynamic data: proxying/forwarding a `Value` you received, test fixtures, or free-form blobs.

```rust
// ❌ BAD — property bag with magic-string keys, stringly-typed dispatch
let state = serde_json::json!({
    "matched": report.matched_count(),
    "missing": report.total_missing_count(),
    "last_run": now,
});
publisher.publish_state("orphans", &serde_json::to_vec(&state)?).await?;

// ✅ GOOD — the shape is a type; the destination is bound to that type
#[derive(Serialize)]
struct OrphanState {
    matched: u64,
    missing: u64,
    last_run: OffsetDateTime,
}

impl StatePayload for OrphanState {
    const NODE: &'static str = "orphans";  // identity lives with the type
}

publisher.publish_state(&OrphanState { /* ... */ }).await?;
```

### Bind the Identity to the Type, Not a String Argument

A `publish(group: &str, bytes: &[u8])` signature is stringly-typed dispatch: the caller must supply the right string *and* the matching bytes, with nothing enforcing they agree. Make the payload type carry its own identity via a trait, and take the typed value:

```rust
// ❌ BAD — any string with any bytes typechecks
async fn publish_state(&self, group: &str, payload: &[u8]) -> Result<()>;

// ✅ GOOD — the type names its own destination and serializes itself
trait StatePayload: Serialize {
    /// The node/topic segment this payload publishes under.
    const NODE: &'static str;
}

async fn publish_state<T: StatePayload>(&self, payload: &T) -> Result<()> {
    let bytes = serde_json::to_vec(payload)?;
    self.publish_raw(T::NODE, &bytes).await
}
```

Now `publish_state(&OrphanState { .. })` is the *only* way to publish an orphan state, the topic string exists in exactly one place, and adding a field is a struct edit the compiler checks. You cannot publish the wrong shape under the wrong node.

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

The only legitimate `#[expect(dead_code)]` on a `Deserialize`/DTO-adjacent struct is a **structural requirement** — a field a macro forces to exist (e.g. `#[durable_object]` requires an `env` field), or a typed-struct API where the container matters but the field value doesn't (e.g. D1's `.first::<T>()` needs a typed row you only check for `Some`/`None`). Those are the only two exceptions; "it documents the schema" is not one of them — use a comment.

## Resources

- Serde Documentation: https://serde.rs
- serde_with Crate: https://docs.rs/serde_with
- Serde Attributes: https://serde.rs/attributes.html
