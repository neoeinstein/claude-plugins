# figue: CLI args, env vars, and layered config

Sources: facet.rs/figue/guide/, figue 4.0.5 sources. (verified) = ran on figue 4.0.5. figue was previously named facet-args.

## Basic CLI (verified)

```rust
use facet::Facet;
use figue::{self as args, FigueBuiltins};

#[derive(Facet, Debug)]
struct Cli {
    /// Enable verbose output          ← doc comment becomes --help text
    #[facet(args::named, args::short = 'v', default)]
    verbose: bool,

    /// Input file
    #[facet(args::positional)]
    input: String,

    /// Adds --help, --version, --completions, schema switches
    #[facet(flatten)]
    builtins: FigueBuiltins,
}

let cli: Cli = figue::from_slice(&["--verbose", "ledger.json"]).unwrap();
let cli: Cli = figue::from_std_args().unwrap();   // real process args
```

`from_slice`/`from_std_args` return `DriverOutcome<T>` with `.unwrap()` / `.unwrap_err()` (figue 4.0.5 driver.rs) — the outcome handles help/version printing paths, not just parse errors. Use `from_slice` in tests so inputs are explicit.

Doc-comment help text requires facet's `doc` feature (on by default). Field names become flag names (`snake_case` → `--snake-case` styling follows the shape's rename rules).

## Attribute vocabulary (clap → figue)

Import alias is required: `use figue::{self as args, ...}` enables the `args::` namespace.

| clap idiom | figue |
|---|---|
| `#[arg(long)]` | `#[facet(args::named)]` |
| `#[arg(short = 'v')]` | `#[facet(args::short = 'v')]` |
| positional `value` | `#[facet(args::positional)]` |
| `#[arg(action = Count)]` (`-vvv`) | `#[facet(args::counted)]` |
| `#[command(subcommand)]` | `#[facet(args::subcommand)]` on an enum field |
| `#[arg(default_value_t = ...)]` | `#[facet(default = expr)]` |
| derive `Parser` help/version | `#[facet(flatten)] builtins: FigueBuiltins` |
| env fallback | `args::env_prefix = "MYAPP"` on a config field |

Subcommands are enum-valued fields (remember `#[repr(u8)]`/`#[repr(C)]` on the enum). Shell completions come from `FigueBuiltins` (`--completions`) or `generate_completions_for_shape`.

## Layered configuration (guide example — not empirically re-tested here)

CLI over env over config file over Rust defaults, one typed model:

```rust
use figue::{self as args, Driver, builder};

#[derive(Facet, Debug)]
struct Args {
    #[facet(args::config, args::env_prefix = "MYAPP")]
    config: ServerConfig,
}

#[derive(Facet, Debug)]
struct ServerConfig {
    #[facet(default = 8080)]
    port: u16,
    #[facet(default = "localhost")]
    host: String,
}

let config = builder::<Args>()?
    .cli(|cli| cli.args(["--config.port", "3000"]))
    .build();
let output = Driver::new(config).run().into_result()?;
// output.value.config.port == 3000; host falls back to default
```

- `args::config` marks a struct field as a layered-config subtree; nested values address as `--config.port` on the CLI and `MYAPP_PORT`-style env vars via `args::env_prefix`.
- Config file formats: `ConfigFormat` impls ship for JSON/JSONC (`JsonFormat`, `JsoncFormat`); `FormatRegistry` handles file-layer format lookup. TOML support goes through additional format crates — verify before promising it.
- `MockEnv` (figue::layers::env) injects fake env vars in tests.
- `generate_json_schemas`/`write_json_schemas` emit JSON Schema for config files.

## Testing pattern

```rust
#[test]
fn parses_flags() {
    let cli: Cli = figue::from_slice(&["-v", "in.csv"]).unwrap();
    assert!(cli.verbose);
}
```

Everything is a plain function call — no global state, no process exit (exit behavior lives in how you handle `DriverOutcome`).
