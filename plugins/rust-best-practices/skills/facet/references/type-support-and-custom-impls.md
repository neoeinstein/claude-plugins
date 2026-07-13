# Type support, the money patterns, and custom Facet representations

Sources: facet.rs/guide/type-support/, facet.rs/reference/container-attributes/ + /reference/field-attributes/ (opaque/proxy/invariants), facet-core 0.46.5 sources (`src/impls/crates/`, `src/types/ty/opaque_adapter.rs`), moneylib 0.13.2 sources. (verified) = compiled/ran on facet 0.46.5 + facet-json 0.46.1 + facet-csv 0.46.1.

## THE MONEY PATTERNS — decision tree

Ordering rule: **(1) native feature flag → (2) field-level `proxy` (pure safe) → (3) container adapter only for zero-copy byte payloads → (4) manual impl, last resort.** Pattern 1 covers the common case (a `rust_decimal::Decimal`-backed amount); Pattern 2 is the fallback when a foreign, compile-time-currency-typed money crate is in play.

### Pattern 1 (default): native `Decimal` + facet-derived Money struct

`rust_decimal::Decimal` **already implements `Facet`** — enable the `rust_decimal` feature on `facet` (facet-core 0.46.5 `src/impls/crates/rust_decimal.rs`; the website type-support page omits it — trust the source). No newtype, no proxy, no unsafe:

```rust
#[derive(Facet, Debug, PartialEq)]
#[facet(deny_unknown_fields)]              // reject silent input drift
#[facet(rename_all = "kebab-case")]        // JSON key convention
#[facet(invariants = Money::is_valid)]     // enforced on deserialize (verified)
struct Money {
    amount: Decimal,     // JSON: "1234.56" (string)
    currency: String,    // or a strid braid / closed enum
}

impl Money {
    fn is_valid(&self) -> bool { self.amount.scale() <= 2 }
}
```

Verified behavior of `Decimal` (a native opaque scalar — `Def::Scalar` with `parse`/`display`/eq/ord/hash in its vtable):

- Serializes as a **JSON string, scale preserved**: `Decimal::from_str("1234.560")` → `"amount":"1234.560"`.
- Deserializes from a JSON **string** losslessly — `0.1234567890123456789012345678` (28 digits) survives exactly.
- Also *accepts* a bare JSON **number**, **but the value routes through f64 and silently truncates to ~17 significant digits** (verified: the 28-digit input came back as `0.12345678901234568`). Fine for 2-decimal money; wrong for anything precision-critical. Emit and demand **strings** on the wire.
- Direct `f64 → Decimal` shape conversion is deliberately `Unsupported` in the vtable (facet-core source comment: floats defeat the purpose of Decimal) — the f64 path above is the JSON parser's number handling, not the vtable conversion.
- Works inside enums, e.g. internally-tagged: `{"kind":"Balance","account":"...","amount":"100.00"}` (verified).
- facet-csv: `Decimal` fields round-trip as plain text (`-42.17`) (verified).
- `invariants` violations reject the value with a spanned error, but the message is generic — `Invariant check failed for 'Money': invariant check failed` (verified). For richer messages use per-field `facet-validate` attrs or a proxy (Pattern 2's `TryFrom` errors carry full custom messages).

Do **not** write a newtype/proxy for bare Decimal — just enable the feature.

### Pattern 2 (foreign money type): field-level proxy — pure safe, zero unsafe

For a foreign, serde-based money type — worked example: **moneylib 0.13.2 `Money<C>`** (rust_decimal-backed, ISO-4217 currency marker types) — you cannot `impl Facet` on it (orphan rule): use `#[facet(opaque, proxy = ...)]` over its string form. This is the reusable shape of "wrap a foreign serde-based type in a facet proxy over its string representation". All verified to compile and round-trip through **facet-json AND facet-csv**:

```rust
use moneylib::{Money, iso::USD};

/// Facet wire form of a USD amount: moneylib's display string, "USD 1,234.56".
#[derive(Facet)]
#[facet(transparent)]                 // serializes as a bare string, not {"0": ...}
pub struct UsdProxy(String);

impl TryFrom<UsdProxy> for Money<USD> {
    type Error = moneylib::MoneyError;
    fn try_from(p: UsdProxy) -> Result<Self, Self::Error> {
        // Parses "USD 1,234.56" AND validates the code against C::CODE —
        // "EUR 100.00" into a Money<USD> field fails deserialization (verified).
        Money::<USD>::from_code_comma_thousands(&p.0)
    }
}

impl TryFrom<&Money<USD>> for UsdProxy {
    type Error = std::convert::Infallible;
    fn try_from(m: &Money<USD>) -> Result<Self, Self::Error> {
        Ok(UsdProxy(m.to_string()))   // Display: "USD 1,234.56"
    }
}

#[derive(Facet, Debug, PartialEq)]
struct Paycheck {
    payee: String,
    #[facet(opaque, proxy = UsdProxy)]
    gross: Money<USD>,
}
```

Verified: JSON `{"payee":"RMAC","gross":"USD 1,234.56"}` round-trips; CSV `RMAC,"USD 1,234.56"` round-trips (the comma inside the money string is CSV-quoted correctly). **The website format matrix listing `proxy` as json/xml-only is stale — facet-csv 0.46.1 handles it** (verified); still test before relying on proxies under toml/yaml/msgpack. Wrong currency yields a spanned, field-pathed error carrying moneylib's own message:

```text
DeserializeError { span: [16..23), path: gross,
  kind: Custom deserialization of shape 'UsdProxy' into 'Opaque' failed:
        [MONEYLIB] currency mismatch: got EUR, expected USD }
```

Notes on the pattern:

- `opaque` hides the non-Facet field from reflection; `proxy` supplies the wire representation. Both go on the field; only the *proxy type* derives Facet. For a field type that *does* implement Facet but needs a different representation, `proxy` alone suffices.
- The `TryFrom` pair is the whole contract — deserialization may fail (validation lives there); serialization is typically `Infallible`. Conversion impedance as a feature: the same boundary discipline as the `From`/`TryFrom` bridges to your serde-based dependencies.
- The generic wrinkle: fields are concrete (`Money<USD>`), and `from_code_comma_thousands` checks `C::CODE`, so one generic `TryFrom` over `C: Currency` covers all currencies while still rejecting mismatches per field.
- Format-specific proxies exist: `#[facet(json::proxy = X)]` — json/xml/html namespaces; resolution order format-specific → generic `proxy` → normal.

### Pattern 3 (do not use for money): container-level `#[facet(opaque = Adapter)]`

Rejected for string-serialized money after reading the contract (facet-core 0.46.5 `src/types/ty/opaque_adapter.rs`):

- `FacetOpaqueAdapter::serialize_map(&SendValue) -> OpaqueSerialize` returns a raw `PtrConst` + `&'static Shape` **pointing into existing memory**. There is nowhere to put a freshly formatted `String` — a pointer to a local would dangle. The API exists for zero-copy byte-payload forwarding (`&[u8]` fields, postcard passthrough), not computed representations.
- `deserialize_build` receives raw **bytes** (`OpaqueDeserialize::Borrowed(&'de [u8])`) — a format-level contract, not a decoded string.
- The dispatch trampolines are `unsafe fn` (`OpaqueAdapterSerializeFn`); ptr/shape pairing correctness is on you.

So it *cannot express* "serialize as computed string", and even where it fits it involves unsafe pointer/shape plumbing. Field-level proxy costs one attribute per field and stays entirely in safe Rust — pay that cost.

### Pattern 4 (last resort): hand-rolled `unsafe impl Facet`

Only for a type you control that must behave like a native scalar in every format crate with no per-field annotation. Copy the model in facet-core 0.46.5 `src/impls/crates/rust_decimal.rs`: `ShapeBuilder::for_sized::<T>("Name").ty(Type::User(UserType::Opaque)).def(Def::Scalar).vtable_indirect(&VTABLE)` with `parse`/`display`/`try_from`/`partial_eq`/`cmp`/`hash` function pointers. Every vtable fn is `unsafe fn` doing raw pointer reads/writes — each body needs a `// SAFETY:` comment justifying the pointee type matches the shape. The FAQ (facet.rs/guide/faq/) steers away from this; if you reach for it, consider contributing the impl upstream instead (facet.rs/contribute/adding-types/).

## Third-party types via feature flags on `facet`

```toml
facet = { version = "0.46", features = ["rust_decimal", "chrono", "uuid"] }
```

| Feature | Types |
|---|---|
| `rust_decimal` | `Decimal` (money Pattern 1; **absent from the website type-support page but real**; also in `all-impls`) |
| `uuid` / `ulid` | `Uuid` / `Ulid` |
| `chrono` | `DateTime<Tz>`, `NaiveDate` (`"2026-01-15"` — verified), `NaiveTime`, `NaiveDateTime` |
| `time` / `jiff02` | time and jiff types |
| `url` | `Url` |
| `camino` | `Utf8Path`, `Utf8PathBuf` |
| `bytes` | `Bytes`, `BytesMut` |
| `ordered-float` | `OrderedFloat`, `NotNan` |
| `indexmap`, `smallvec`, `semver`, `num-complex`, `iddqd`, `ruint`, `lock_api`, `yoke`, `compact_str`, `smartstring`, `smol_str`, `bytestring`, `tendril` | per-crate types |
| `nonzero`, `net` | std `NonZero*`; `IpAddr`/`SocketAddr` family |
| `tuples-12` | tuples beyond 4 elements (default supports up to 4) |

Other facet features: `doc` (default; doc comments in shapes — figue help needs it; strip in release with `--cfg facet_no_doc` rustflag), `helpful-derive` (default; typo suggestions in derive errors), `reflect` (Peek/Partial re-exports), `alloc` for no_std.

## Foreign non-money types

Same tiering as money. `#[facet(opaque)]` alone hides a field (not serialized, no round-trip); add `proxy` to make it serializable. A non-Facet *error source* inside a `#[facet(derive(Error))]` enum also needs `#[facet(opaque)]` — see errors-and-validation.md. `TryFrom` failures become deserialization errors, so proxies double as validators.

## Recursive types

```rust
#[derive(Facet)]
struct Node {
    #[facet(recursive_type)]
    lhs: Option<Box<Node>>,
    #[facet(recursive_type)]
    rhs: Option<Box<Node>>,
}
```

Required on any field that closes a type cycle (facet.rs/guide/faq/).
