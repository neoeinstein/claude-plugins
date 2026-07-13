# `#[facet(...)]` attribute reference (facet 0.46.x)

Sources: facet.rs/reference/container-attributes/, /reference/enum-attributes/, /reference/field-attributes/, /guide/serde/. Items marked (verified) were compiled and run against facet 0.46.5 + facet-json 0.46.1.

## serde → facet mapping

Facet accepts **expressions and closures directly** where serde requires quoted function-path strings.

| serde | facet | Notes |
|---|---|---|
| `#[serde(deny_unknown_fields)]` | `#[facet(deny_unknown_fields)]` | (verified) errors carry span + field name |
| `#[serde(default)]` (container) | `#[facet(default)]` + `impl Default` | struct-level: missing fields from `Default` |
| `#[serde(default)]` (field) | `#[facet(default)]` | uses `Default::default()` |
| `#[serde(default = "path")]` | `#[facet(default = 42)]` / `#[facet(default = some_fn())]` | any expression, not a string |
| `#[serde(rename = "x")]` | `#[facet(rename = "x")]` | field or variant |
| `#[serde(rename_all = "camelCase")]` | `#[facet(rename_all = "camelCase")]` | PascalCase, camelCase, snake_case, SCREAMING_SNAKE_CASE, kebab-case, SCREAMING-KEBAB-CASE |
| `#[serde(skip)]` | `#[facet(skip, default)]` | facet requires a default with skip |
| `#[serde(skip_serializing)]` | `#[facet(skip_serializing)]` | |
| `#[serde(skip_deserializing)]` | `#[facet(skip_deserializing, default)]` | |
| `#[serde(skip_serializing_if = "Option::is_none")]` | `#[facet(skip_serializing_if = Option::is_none)]` | (verified) also closures: `\|n\| *n == 0` |
| — (no serde equivalent) | `#[facet(skip_unless_truthy)]` | (verified) omits falsy: `false`, 0/NaN, empty collection/string, `None` |
| — | `#[facet(skip_all_unless_truthy)]` (container) | applies to every field |
| `#[serde(transparent)]` | `#[facet(transparent)]` | newtype serializes as inner value |
| `#[serde(flatten)]` | `#[facet(flatten)]` | works inside internally-tagged enum variants too |
| `#[serde(tag = "type")]` | `#[facet(tag = "type")]` | internal tagging (verified with Decimal payloads) |
| `#[serde(tag = "t", content = "c")]` | `#[facet(tag = "t", content = "c")]` | adjacent tagging |
| `#[serde(untagged)]` | `#[facet(untagged)]` | variants tried in definition order |
| `#[serde(other)]` | `#[facet(other)]` on a variant | catch-all; can capture tag/payload via field-level `#[facet(tag)]`/`#[facet(content)]` |
| `#[serde(with = ...)]` / remote types | `#[facet(proxy = ProxyType)]` | see type-support-and-custom-impls.md |
| `#[serde(borrow)]` | — no equivalent | use `from_str_borrowed` instead |

## Container attributes

- `deny_unknown_fields` — reject unknown input fields. Put this on every struct that parses external data.
- `default` — struct-level; requires `Default` impl; missing fields filled from it.
- `rename_all = "..."` — case convention for all fields/variants.
- `transparent` — single-field newtype forwards to inner type.
- `opaque` — hide internal structure; type can't serialize without a `proxy` or adapter. `#[facet(opaque = AdapterType)]` takes a `FacetOpaqueAdapter` (container-level only).
- `pod` — asserts no invariants; enables reflection-based mutation. Mutually exclusive with `invariants` (compile error if both).
- `invariants = validate_fn` — `fn(&Self) -> bool`, run when the deserialized value is finalized (`Partial::build()`). Whole-value / cross-field validation. Not supported directly on enums — wrap in a struct. Nested structs' invariants are NOT re-checked by the parent; validate explicitly.
- `skip_all_unless_truthy` — see field `skip_unless_truthy`.
- `type_tag = "com.example.User"` — identifier for self-describing formats.
- `crate = path::to::facet` — for re-exported facet (strid uses `#[facet(crate = ::strid::facet)]` internally).
- `metadata_container` — transparent wrapper preserving `span`/`doc`/`tag` metadata for formats that support it (Styx); JSON ignores metadata. Exactly one non-metadata field.

## Enum attributes

**Enums must have `#[repr(u8)]` or `#[repr(C)]` — compile error otherwise.** (verified) This is a *memory-layout / compile* requirement only; it does **not** put integers on the wire. **Unit (dataless) variants serialize as their variant-name string** — `Kind::Fee` → `"Fee"` (verified), like serde — and `#[facet(rename_all = "kebab-case")]` (or `#[facet(rename = "...")]` per variant) controls the casing: `CardPayment` → `"card-payment"` (verified). Prefer these semantic string variants; never treat `#[repr(u8)]` as "serialize as integer". (The repr requirement is enforced by the `Facet` derive macro — `error: Facet requires enums to have an explicit representation` — because reflection needs a defined discriminant layout to peek/poke variants; it is NOT stated in the facet.rs enum-attributes reference, only surfaced as the compile error.)

- Default (variants WITH data) = externally tagged: `{"Text": "hello"}`.
- `#[facet(tag = "type")]` — internal: `{"type": "Click", "x": 10}` (verified).
- `#[facet(tag = "t", content = "c")]` — adjacent.
- `#[facet(untagged)]` — bare value; first matching variant in definition order wins (typed formats). Text formats (XML) use two-tier matching: parseable types first, string fallback second.
- `#[facet(other)]` on one variant — catch-all for unknown tags. `Unknown(String)` captures the tag name; struct variants can use `#[facet(tag)]`/`#[facet(content)]` fields for self-describing formats.

## Field attributes

- `rename = "..."` — overrides `rename_all`.
- `default` / `default = expr` — expression evaluated for missing field. Type-suffix literals (`8080u16`) disambiguate. **Required on `Vec`/`HashMap`/`HashSet` fields that may be absent from input** (verified: no implicit collection default in 0.46.x, contrary to the serde-comparison page). `Option<T>` needs nothing — missing → `None` (verified).
- `skip` (+ `default`), `skip_serializing`, `skip_deserializing` (+ `default`).
- `skip_serializing_if = predicate` — path or closure, unquoted.
- `skip_unless_truthy` — built-in truthiness predicate per type.
- `sensitive` — facet-pretty renders `[REDACTED]` (verified); serialization is unaffected.
- `flatten` — merge nested struct's fields into parent; also valid inside internally-tagged enum variants for shared fields.
- `proxy = ProxyType` — serialize via conversion type (see type-support-and-custom-impls.md). Format-specific: `#[facet(json::proxy = X)]` (json/xml/html only; resolution: format-specific → generic proxy → normal).
- `opaque` — field hidden; combine with `proxy` to make it serializable.
- `recursive_type` — required on fields that create type cycles (`Option<Box<Node>>`).
- `child` — hierarchical formats (XML) child node.
- `trailing` — last-field opaque byte payload for binary formats; must be last, opaque, non-flatten.
- `metadata = "span"|"doc"|"tag"` — inside a `metadata_container`.

## Extension attributes

Format- and tool-specific attributes live in namespaces and require importing the crate under an alias so the derive recognizes the prefix (facet.rs/guide/faq/):

```rust
use facet_validate as validate;   // enables #[facet(validate::min = 1)]
use figue as args;                // enables #[facet(args::named)]
use facet_xml as xml;             // enables #[facet(xml::property)]
```

"Compile errors mention extension attributes I'm not using" almost always means the aliased import is missing.
