# Data formats: facet-json, facet-csv, facet-toml/yaml

Sources: facet.rs/facet-json/guide/, facet-csv 0.46.1 sources, facet.rs/reference/format-crate-matrix/. (verified) = ran against facet-json 0.46.1 / facet-csv 0.46.1.

## facet-json (0.46.1)

### Deserialize

```rust
let v: T = facet_json::from_str(input)?;          // &str → owned T
let v: T = facet_json::from_slice(bytes)?;        // &[u8] → owned T
let v: T<'_> = facet_json::from_str_borrowed(input)?;   // zero-copy &str fields
let v: T<'_> = facet_json::from_slice_borrowed(bytes)?;
let v: T = facet_json::from_str_jsonc(input)?;    // JSON with comments (also _slice/_borrowed variants)
```

All return `Result<T, DeserializeError>`. Errors are span-aware (verified):

```text
DeserializeError { span: [11..12), path: <root>, kind: missing field `tags` in type `Implicit` }
DeserializeError { span: [11..12), path: <root>, kind: Validation failed for field 'Validated::count': must be >= 1, got 0 }
```

Propagate with `?`; the span/path make bad input debuggable without extra context.

### Serialize

```rust
let s: String = facet_json::to_string(&value)?;          // compact
let s: String = facet_json::to_string_pretty(&value)?;   // indented
let b: Vec<u8> = facet_json::to_vec(&value)?;            // + to_vec_pretty
facet_json::to_writer_std(writer, &value)?;              // io::Result; + _pretty
// SerializeOptions control indentation/bytes rendering:
facet_json::to_string_with_options(&value, &opts)?;
```

**Every serialize function returns `Result`** — `SerializeError<JsonSerializeError>` (verified; the website getting-started sample omitting `.unwrap()` predates this API).

`peek_to_string` / `peek_to_writer_std` serialize an already-reflected `Peek` value — used when writing generic tooling, not everyday code.

### Behavior notes (verified)

- `Decimal` → `"1234.560"` (string, scale preserved); parses losslessly from string; a bare JSON number is accepted but truncates through f64 — see type-support-and-custom-impls.md.
- `chrono::NaiveDate` → `"2026-01-15"`; `DateTime<Utc>` → RFC 3339 string.
- strid braids → bare strings (`{"account":"Assets:Checking"}`).
- Missing `Option` → `None`; missing collection → **error** unless `#[facet(default)]`.
- Unknown fields silently ignored unless `#[facet(deny_unknown_fields)]`.
- `facet-validate` constraints are enforced during deserialization.

## facet-csv (0.46.1)

Deliberately minimal (crate docs): flat rows only — no nested structs, no sequence-valued fields, enums as unit-variant strings only, everything parsed from strings.

```rust
#[derive(Facet, Debug, PartialEq)]
struct CsvRow {
    date: String,
    amount: Decimal,
    payee: String,
}

// ONE ROW PER CALL — from_str parses a single record, no header line (verified):
let row: CsvRow = facet_csv::from_str("2026-01-15,-42.17,\"ArbiterPay, LLC\"")?;

// Reading a file: skip the header yourself, then per line:
for line in data.lines().skip(1) {
    let row: CsvRow = facet_csv::from_str(line)?;
}

// Serialize ONE record; emits a trailing newline, quotes/escapes as needed (verified):
let line = facet_csv::to_string(&row)?;   // "2026-01-15,-42.17,\"ArbiterPay, LLC\"\n"
// Also: to_vec, to_writer(&mut w, &row)
```

**`facet_csv::to_string(&vec_of_rows)` fails** with `CsvSerializeError { msg: "CSV does not support sequences" }` (verified). Write the header and loop rows through `to_writer` yourself. Columns bind by position, so field order in the struct must match column order in the file; `from_str_borrowed`/`from_slice` variants exist like JSON's.

For quirky real-world CSV (ragged rows, BOMs, multi-line cells at scale), the crate docs themselves recommend a dedicated CSV library — pair the `csv` crate for framing with facet for the typed row if needed.

## facet-toml / facet-yaml (0.46.1)

Same shape-driven model; both serialize and deserialize (docs.rs/facet-toml, docs.rs/facet-yaml). Unverified — treat details accordingly and check the format matrix before relying on edge types.

## Format support matrix highlights (facet.rs/reference/format-crate-matrix/)

- `proxy`/`opaque` attributes: the matrix lists json and xml only, **but facet-csv 0.46.1 handles field-level `opaque, proxy` fine** (verified round-trip of a proxied moneylib field, including CSV-quoting of the proxy string). Still unverified under toml/yaml/msgpack/postcard — test before relying on it there. Types with *native* Facet impls (Decimal, Uuid, chrono) are scalars, not proxies, and work everywhere the matrix shows scalar support.
- `char`: unsupported in JSON (🚫) per matrix.
- TOML: no `HashSet`/`BTreeSet`, no `Box/Rc/Arc`, string map keys only.
- The website matrix can lag releases (it listed facet-csv as serialize-only; 0.46.1 deserializes fine — verified). When it matters, check the crate source or write a 5-line round-trip test.
