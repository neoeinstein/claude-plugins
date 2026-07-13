# Errors, validation, and defaults

Sources: facet.rs/facet-error/guide/, /facet-validate/guide/, /facet-default/guide/, /reference/container-attributes/ (invariants). (verified) = ran on facet-error/facet-validate/facet-default 0.46.5 + facet-json 0.46.1.

## facet-error: thiserror-style derives (verified)

Doc comments become `Display`; fields interpolate by position (`{0}`) or name (`{field}`):

```rust
use facet::Facet;
use facet_error as error;   // enables error:: namespace attrs

#[derive(Facet, Debug)]
#[facet(derive(Error))]
#[repr(u8)]                  // enums always need a repr under facet
enum PipelineError {
    /// missing account: {0}
    MissingAccount(String),

    /// bad row {row}: {reason}
    BadRow { row: u32, reason: String },

    /// input file could not be read
    Read(#[facet(opaque)] #[facet(error::from)] std::io::Error),
}
```

- Generates `Display` + `std::error::Error` (verified: `e.to_string() == "missing account: Assets:Checking"`).
- `#[facet(error::from)]` marks the source AND generates `From` (like thiserror `#[from]`); `#[facet(error::source)]` chains `source()` without the conversion. Verified: `From<io::Error>` conversion works and `source()` returns the io error.
- **Non-Facet source types (like `std::io::Error`) need `#[facet(opaque)]` on the field** — the enum derives Facet, so every field must be Facet or opaque; without it the derive fails with "the trait Facet is not implemented" (verified). The guide's examples sidestep this by using a source type that itself derives Facet.
- The enum is still a Facet type: serializable, pretty-printable, rediff-able.
- At an application boundary, this replaces thiserror for facet-native crates; where the house style wants miette, wrap the facet-error enum as the diagnostic source — the two compose the same way thiserror does.

## facet-validate: constraints enforced at deserialization (verified)

```rust
use facet::Facet;
use facet_validate as validate;   // alias required for validate:: attrs

#[derive(Facet, Debug)]
struct Product {
    #[facet(validate::min_length = 1, validate::max_length = 100)]
    title: String,
    #[facet(validate::min = 0)]
    price_cents: i64,
    #[facet(validate::custom = validate_currency)]
    currency: String,
}

fn validate_currency(s: &str) -> Result<(), String> {
    matches!(s, "USD" | "EUR" | "GBP")
        .then_some(())
        .ok_or_else(|| format!("invalid currency code: {s}"))
}
```

Built-ins: `validate::min`/`max` (numeric), `min_length`/`max_length`, `email`, `url`, `regex = r"..."`, `contains = "..."`, `custom = fn` (`fn(&T) -> Result<(), String>`).

**facet-json enforces these automatically during `from_str`** (verified):

```text
Err(DeserializeError { span: [11..12), path: <root>,
    kind: Validation failed for field 'Validated::count': must be >= 1, got 0 })
```

The crate only needs to be linked (`use facet_validate as validate;`) — no registration call.

## Container invariants: cross-field validation

`facet-validate` is per-field. For relationships between fields use `#[facet(invariants = fn)]` (`fn(&Self) -> bool`), run when the deserialized value is finalized:

```rust
#[derive(Facet)]
#[facet(invariants = Range::is_valid)]
struct Range { min: u32, max: u32 }

impl Range {
    fn is_valid(&self) -> bool { self.min <= self.max }
}
```

Caveats (facet.rs/reference/container-attributes/): returns only `bool` (no message); top-level only — nested structs' invariants are not re-run by the parent; not directly usable on enums (wrap in a struct); mutually exclusive with `pod`.

## facet-default: per-field Default derivation (verified)

```rust
use facet_default as _;   // link the plugin

#[derive(Facet, Debug, PartialEq)]
#[facet(derive(Default))]
struct Settings {
    #[facet(default = "report")]        // literal; String fields convert
    out_dir: String,
    #[facet(default = 3u32)]            // suffix disambiguates
    lookback_months: u32,
    verbose: bool,                      // falls back to bool::default()
}
```

Enum default variant: `#[facet(default::variant)]` on the variant, with `#[facet(derive(Default))]` + `#[repr(u8)]` on the enum.

The same `#[facet(default = ...)]` attributes also fill **missing fields during deserialization** — one annotation serves both `Default::default()` and lenient parsing. Remember the 0.46.x rule: collections need an explicit `#[facet(default)]` to tolerate absence; `Option` does not.
