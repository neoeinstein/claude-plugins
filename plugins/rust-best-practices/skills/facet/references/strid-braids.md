# strid braids: strongly typed string IDs

Sources: strid 10.0.0 sources + rustdoc (docs.rs/strid), facet.rs/strid/. strid is the facet-monorepo fork of aliri_braid, updated for edition 2024 with built-in Facet support. (verified) = ran on strid 10.0.0.

## Defining a braid

```rust
use strid::braid;

/// A beancount-style account name.
#[braid(serde)]
pub struct AccountId;
```

`#[braid]` rewrites the unit struct into a `String` wrapper and generates a borrowed twin:

- Owned `AccountId` + borrowed `AccountIdRef` (like `PathBuf`/`Path`). Naming: `FooBuf` → `Foo`; `FooString` → `FooStr`; override with `#[braid(ref_name = "...")]`.
- API: `AccountId::new(String)` (returns `Result` for validated braids, plain value otherwise), `from_static(&'static str)`, `.as_str()`, `.take()` → `String`; `AccountIdRef::from_static`, `.to_owned()`.
- Derives `Hash, PartialEq, Eq`, Clone/Debug/Display/Ord (each omittable, e.g. `#[braid(ord = "omit")]`).
- **Facet is always derived** — the macro emits `#[derive(::strid::facet::Facet)]` `#[facet(crate = ::strid::facet, transparent)]` (strid-macros 10.0.0 codegen). No opt-in flag. strid re-exports facet (`strid::facet`), so braids work with facet-json et al. even if your crate's `facet` version differs slightly.
- `serde` in the argument list opts into serde impls — needed to hand braids to foreign serde-based dependencies.

## Serialization (verified)

Braids serialize as bare strings in both facet and serde:

```rust
#[derive(Facet, Debug, PartialEq)]
struct Posting { account: AccountId, tag: Tag }
// facet_json::to_string → {"account":"Assets:Checking","tag":"officiating"}
```

Round-trips under facet-json; usable as struct fields anywhere a `String` field would be.

## Validated and normalized braids

```rust
#[braid(serde, validator)]
pub struct Tag;

impl strid::Validator for Tag {
    type Error = InvalidTag;
    fn validate(s: &str) -> Result<(), Self::Error> {
        if !s.is_empty() && s.bytes().all(|b| b.is_ascii_lowercase()) { Ok(()) }
        else { Err(InvalidTag) }
    }
}
```

- `validator` (self) or `validator = "OtherType"` (foreign validator). `Tag::new()` returns `Result<Tag, InvalidTag>`; `from_static` panics on invalid input.
- `normalizer` similarly implements `strid::Normalizer` for canonicalizing on construction (e.g. lowercasing); normalized braids re-normalize on deserialize under serde.
- Error types need `From<Infallible>`; `strid::from_infallible!(MyError)` generates it.
- Custom backing strings: `#[braid(no_expose)] pub struct UserId(CompactString);` — any type with the required trait set (Clone/Debug/Display/Eq/Hash/From<&str>/AsRef<str>/Into<String>...).

## CRITICAL: facet deserialization bypasses validation (verified)

The generated Facet impl is `transparent` with **no invariants wiring** — strid-macros 10.0.0 contains no `invariants` emission. Consequences, verified empirically:

```rust
// Tag validator rejects uppercase. Yet:
facet_json::from_str::<Posting>(r#"{"account":"a","tag":"NOT-LOWERCASE"}"#)
    // → Ok(...)  — INVALID VALUE ADMITTED via facet
serde_json::from_str::<Tag>(r#""NOT-LOWERCASE""#)
    // → Err("invalid tag") — serde enforces the validator
```

Rules for correctness until strid wires validation into facet:

1. Where a validated/normalized braid's guarantee matters, don't trust a value that arrived through **facet** deserialization. Either accept `String` in the wire-facing struct and convert with `Tag::new(s)?` in a constructor, or re-validate after parse (`Tag::validate(t.as_str())`).
2. Unvalidated braids (pure newtypes like `AccountId`) are safe under facet — there is no invariant to bypass.
3. serde paths (the serde bridge) remain fully validated.

## Bridging to foreign serde-based dependencies

Give domain braids `#[braid(serde)]` and convert at the boundary with `From`/`TryFrom` between your facet-native models and the serde-based crate's types. A braid's `.as_str()`/`.take()` and `new()`/`from_static()` make those conversions cheap and explicit. Avoid dual-deriving whole domain structs when a boundary conversion will do.
