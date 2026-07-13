---
name: facet
description: "Use when writing Rust code with the facet ecosystem - derive(Facet), facet-json/facet-csv serialization, figue CLI/config, facet-error derives, facet-validate constraints, strid braids, rediff structural diffs, or serializing rust_decimal::Decimal/jiff/chrono types under facet. Serde-to-facet attribute mapping, Decimal/money patterns, and gotchas verified against facet 0.46."
---

# facet-rs: idiomatic facet ecosystem usage

## Overview

facet (https://facet.rs) is a reflection library: `#[derive(Facet)]` generates a `&'static Shape` describing the type once, and format crates (facet-json, facet-csv, ...) interpret that shape at runtime. One derive powers serialization, pretty-printing, diffing, CLI parsing, and schema generation. It trades raw speed for features — serde monomorphizes per type×format and is faster in hot loops.

Verified against facet 0.46.5 / facet-json 0.46.1 / strid 10.0.0 (2026-07-12).

## Critical gotchas (memorize these)

1. **Enums require an explicit repr — but that's memory-only, not the wire form.** `#[derive(Facet)]` on an enum needs `#[repr(u8)]`/`#[repr(C)]` or it's a compile error ("Facet requires enums to have an explicit representation"). This does **not** serialize as an integer: unit (dataless) variants serialize as their **variant-name string** (`Kind::Fee` → `"Fee"`), like serde; use `#[facet(rename_all = "kebab-case")]` to control casing (`"card-payment"`). Never read `#[repr(u8)]` as "serialize as integer".
2. **`rust_decimal::Decimal` implements `Facet` natively** — enable the `rust_decimal` feature on `facet`. It serializes as a **JSON string with scale preserved** (`"1234.560"`). Deserializing from a JSON **string is lossless** (28 digits); a bare JSON **number silently truncates through f64** (~17 significant digits). Keep money as strings on the wire. **No newtype or hand-written impl needed.** For a foreign, serde-based money type, use the pure-safe field-level proxy — see "THE MONEY PATTERNS" in `references/type-support-and-custom-impls.md`.
3. **`Option<T>` implicitly defaults to `None` when missing; `Vec`/`HashMap` do NOT** in released 0.46.x — a missing collection field is a hard error despite the serde-comparison page claiming otherwise. Write `#[facet(default)]` on every collection field that may be absent.
4. **strid validated braids are NOT validated by facet deserialization.** `#[braid(serde, validator)]` enforces the validator under serde only; facet's derived impl is transparent and bypasses `Validator::validate`. Re-validate after facet deserialization or accept raw `String` at the boundary and convert with `Type::new()`.
5. **Always put `#[facet(deny_unknown_fields)]` on structs that parse external input.** Unknown fields are silently ignored by default.
6. **facet-csv is one-record-per-call and headerless.** `from_str` parses a single row; serializing a `Vec<Row>` fails with "CSV does not support sequences". Iterate lines yourself.
7. **`facet_json::to_string` returns `Result`** — the website getting-started sample that omits `.unwrap()` is stale.
8. **facet-validate constraints ARE enforced during facet-json deserialization** — errors like `Validation failed for field 'T::count': must be >= 1, got 0` come back with input spans.
9. **`#[derive(Facet)]` expands to `unsafe impl Facet`** — incompatible with crate-wide `forbid(unsafe_code)`. Step down to `unsafe_code = "deny"` + targeted `#[expect(unsafe_code, reason = "…")]`; see the unsafe ladder in the `rust-best-practices` skill's `references/lint-setup.md`.

## Cargo setup

```toml
[dependencies]
facet = { version = "0.46", features = ["rust_decimal", "chrono", "uuid"] }
facet-json = "0.46"
facet-csv = "0.46"       # if reading/writing CSV
facet-error = "0.46"     # thiserror-style derives
facet-validate = "0.46"  # field constraints
rediff = "0.46"          # structural diff assertions (dev-dependency)
strid = "10"             # braids (re-exports facet)
figue = "4"              # CLI/config (if building a binary)
```

Format crates version independently of `facet` (0.46.1 vs 0.46.5 is normal). `default` features on `facet` include `std`, `helpful-derive` (typo suggestions), and `doc` (doc comments in shapes — figue help text needs this).

## Core idiom

```rust
use facet::Facet;
use rust_decimal::Decimal;

#[derive(Facet, Debug, PartialEq)]
#[facet(deny_unknown_fields)]
struct Transaction {
    date: chrono::NaiveDate,     // "2026-01-15"
    amount: Decimal,             // "12.34" — string in JSON, scale preserved
    payee: String,
    note: Option<String>,        // missing → None (implicit)
    #[facet(default)]            // REQUIRED for collections that may be absent
    tags: Vec<String>,
}

let t: Transaction = facet_json::from_str(json)?;   // spans in errors
let out = facet_json::to_string(&t)?;               // compact; _pretty for indented
```

## What to load when

| Task | Reference file |
|---|---|
| Any `#[facet(...)]` attribute; porting serde attributes | `references/attributes.md` |
| facet-json API, JSONC, error spans; facet-csv rows; TOML/YAML; format support matrix | `references/formats-json-csv.md` |
| **The money patterns** (native Decimal, foreign-type proxy, safety tiering); which types implement Facet (Uuid, chrono...); proxy/opaque for foreign types | `references/type-support-and-custom-impls.md` |
| Defining/using strid braids; validation; serde bridging | `references/strid-braids.md` |
| CLI args, env vars, layered config with figue | `references/figue-cli.md` |
| Error enums (facet-error), validation (facet-validate, invariants), defaults (facet-default) | `references/errors-and-validation.md` |
| Round-trip tests, rediff assertions, correctness conventions | `references/testing-with-rediff.md` |

For choosing between facet and serde as a stack, see the serde-vs-facet stack table at the head of the `rust-best-practices` skill's `references/serde.md`.
