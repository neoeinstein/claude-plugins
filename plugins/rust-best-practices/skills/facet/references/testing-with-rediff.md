# Testing facet code: rediff and correctness conventions

Sources: facet.rs/rediff/, rediff 0.46.1 sources. (verified) = ran on rediff 0.46.1 + facet-json 0.46.1.

## rediff: structural, path-aware diffs (verified)

rediff compares two Facet values through their shapes — no `PartialEq`/`Debug` derives needed on the type — and renders exactly what differs:

```rust
use rediff::assert_same;

#[test]
fn parity() {
    let expected: Report = facet_json::from_str(oracle_json)?;
    let actual = build_report(&inputs);
    assert_same!(expected, actual);
}
```

On failure the panic message shows per-field paths and both values (verified, colors elided):

```text
assertion `assert_same!(left, right)` failed
{
    amount: 1.10 → 2.20
    currency: "USD" → "EUR"
}
```

Macro family (rediff 0.46.1 lib.rs):

- `assert_same!(a, b)` / `assert_same_with!(a, b, config)` — strict structural equality.
- `debug_assert_same!` / `debug_assert_same_with!` — debug builds only.
- `assert_sameish!` / variants — lenient comparison (tolerates certain representational differences); prefer strict `assert_same!` unless you need it.
- Opaque types can't be structurally compared — they yield `Sameness::Opaque` (facet.rs/reference/container-attributes/). Values with `#[facet(opaque)]` fields won't diff through those fields.
- `DiffReport` and the `diff::` module expose the diff programmatically when a test wants to inspect rather than assert.

rediff output honors `#[facet(sensitive)]`-adjacent tooling conventions but the diff shows real values — don't run it over live secrets in CI logs.

## Round-trip property tests

Every wire-facing type should round-trip. Minimum viable version:

```rust
#[test]
fn transaction_round_trips() {
    let t = sample_transaction();
    let json = facet_json::to_string(&t).unwrap();
    let back: Transaction = facet_json::from_str(&json).unwrap();
    assert_same!(t, back);
}
```

With proptest, generate values and assert `deserialize(serialize(x)) == x`. High-value targets:

- `Decimal` fields — scale must survive (`"1.10"` ≠ `"1.1"` as strings; `Decimal` keeps scale — verified).
- Braids — bare-string representation.
- Enums — every variant, especially tagged representations.
- `Option`/collection fields — include `None`/empty and missing-key inputs.

CSV round-trips are per-row: `facet_csv::from_str(facet_csv::to_string(&row)?.trim_end())?` (verified — serialization appends `\n`).

## Correctness conventions

1. **Test the failure paths**: unknown field, missing required field, validation violation. The `DeserializeError { span, path, kind }` payloads are stable enough to assert `kind` text against.
2. **serde parity when bridging**: for a type that must exist in both worlds, one test asserting `facet_json::to_string(&x)? == serde_json::to_string(&x)?` pins the wire formats together (verified this holds for plain structs).
