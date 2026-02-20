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
| Skip None values | `#[serde(skip_serializing_if = "Option::is_none")]` |
| Default for missing | `#[serde(default)]` |
| Validate on deserialize | `#[serde(try_from = "RawType")]` |
| Internally tagged enum | `#[serde(tag = "type")]` |
| Reject unknown fields | `#[serde(deny_unknown_fields)]` |
| Override trait bounds | `#[serde(bound = "T: MyTrait")]` |
| Zero-copy string | `&'a str` field |
| Zero-copy with fallback | `Cow<'a, str>` with `#[serde(borrow)]` |

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
