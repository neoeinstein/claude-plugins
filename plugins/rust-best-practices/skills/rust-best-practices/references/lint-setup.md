# Lint Setup

Setup-time authority: recommended workspace lint config, per-crate inheritance, the unsafe ladder, enforcement. For responding to a lint that fired, see `responding-to-lints.md`.

## Recommended workspace config

Comprehensive and safe-by-default: adopt the whole set, opt out by exception. Two entries are rustc lints, not clippy — they go under `[workspace.lints.rust]` or you get `unknown lint` (E0602), which breaks `-D warnings`.

```toml
[workspace.lints.clippy]
all = { level = "warn", priority = -1 }
pedantic = { level = "warn", priority = -1 }
# Don't panic
string_slice = "warn"
indexing_slicing = "warn"
unwrap_used = "warn"
get_unwrap = "warn"
unwrap_in_result = "warn"
panic = "warn"
panic_in_result_fn = "warn"
todo = "warn"
unimplemented = "warn"
unreachable = "warn"
unchecked_time_subtraction = "warn"
# Don't fail silently
let_underscore_future = "warn"
let_underscore_must_use = "warn"
unused_result_ok = "warn"
map_err_ignore = "warn"
assertions_on_result_states = "warn"
# Async / memory / unsafe hygiene
await_holding_lock = "warn"
await_holding_refcell_ref = "warn"
large_futures = "warn"
mem_forget = "warn"
undocumented_unsafe_blocks = "warn"
multiple_unsafe_ops_per_block = "warn"
unnecessary_safety_doc = "warn"
unnecessary_safety_comment = "warn"
# Numeric — cast_* are tripwires; money stays Decimal (type-safety.md)
float_cmp = "warn"
float_cmp_const = "warn"
lossy_float_literal = "warn"
cast_sign_loss = "warn"
cast_possible_wrap = "warn"
cast_precision_loss = "warn"
cast_possible_truncation = "warn"
invalid_upcast_comparisons = "warn"
# Easy-to-avoid mistakes
rc_mutex = "warn"
debug_assert_with_mut_call = "warn"
iter_not_returning_iterator = "warn"
expl_impl_clone_on_copy = "warn"
infallible_try_from = "warn"
dbg_macro = "warn"
# Every suppression must be an intentional #[expect(..., reason)]
allow_attributes = "warn"
allow_attributes_without_reason = "warn"
# API / hygiene tripwires
as_pointer_underscore = "warn"
clone_on_ref_ptr = "warn"
collection_is_never_read = "warn"
deref_by_slicing = "warn"
empty_drop = "warn"
empty_enum_variants_with_brackets = "warn"
empty_structs_with_brackets = "warn"
fn_to_numeric_cast_any = "warn"
if_then_some_else_none = "warn"
infinite_loop = "warn"
redundant_type_annotations = "warn"
renamed_function_params = "warn"
same_functions_in_if_condition = "warn"
should_panic_without_expect = "warn"
unneeded_field_pattern = "warn"
unseparated_literal_suffix = "warn"
# Cargo hygiene — cherry-pick, don't enable the whole `cargo` group
negative_feature_names = "warn"
redundant_feature_names = "warn"
wildcard_dependencies = "warn"

[workspace.lints.rust]
ambiguous_negative_literals = "warn"
elided_lifetimes_in_paths = "warn"
keyword_idents_2024 = "warn"
non_ascii_idents = "warn"
non_local_definitions = "warn"
redundant_imports = "warn"
redundant_lifetimes = "warn"
trivial_numeric_casts = "warn"
# never downgrade: this forbid keeps every expect() self-expiring
unfulfilled_lint_expectations = "forbid"
unreachable_pub = "warn"
unsafe_op_in_unsafe_fn = "warn"
unused_import_braces = "warn"
unused_lifetimes = "warn"
unused_macro_rules = "warn"
unused_qualifications = "warn"
```

## Additions for published / library crates

Distributed crates should also enforce API-doc and naming hygiene. Internal/app crates may skip these.

```toml
[workspace.lints.rust]
missing_docs = "warn"
missing_debug_implementations = "warn"
unnameable_types = "warn"

[workspace.lints.clippy]
cargo_common_metadata = "warn"
```

## Opt out by exception

`allow` belongs only here in config; source uses `#[expect(..., reason)]` only. Common exceptions:

| Lint | Set to `allow` when |
|---|---|
| `print_stdout` / `print_stderr` | a CLI legitimately prints to stdio |
| `module_name_repetitions` | the repeated segment reads clearest |
| `multiple_crate_versions` | a real transitive tree carries duplicate versions |
| `implicit_hasher` | internal helpers take concrete `HashMap`/`HashSet`, no custom-hasher caller |

## Test relaxations (clippy.toml)

```toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
allow-panic-in-tests = true
allow-indexing-slicing-in-tests = true
allow-dbg-in-tests = true
```

These cover `#[cfg(test)]` code only. Helper fns in `tests/` integration files are not test items — suppress there with `#[expect(clippy::unwrap_used, reason = "tests")]`.

## Inheritance — required in every crate

Cargo does NOT inherit workspace lints. Every member crate needs:

```toml
[lints]
workspace = true
```

A crate missing this line silently escapes every lint above — a real hazard when a new crate is scaffolded. Guard it with [`cargo-workspace-lints`](https://github.com/JarredAllen/cargo-workspace-lints), which fails if any member lacks the inheritance.

## The unsafe ladder

1. Prefer `unsafe_code = "forbid"` workspace-wide (`[workspace.lints.rust]`).
2. If a derive macro or FFI genuinely needs unsafe — reflection derives that expand to `unsafe impl` (`#[derive(Facet)]`), `bytemuck`/`zerocopy` derives — step down to `unsafe_code = "deny"` and mark the specific items/modules with `#[expect(unsafe_code, reason = "…")]`. `forbid` cannot be locally overridden; `deny` can.
3. Add `#![forbid(unsafe_code)]` in each crate that does not need the affordance — a stronger per-crate guarantee that fails loudly if a later derive introduces unsafe.

serde derives expand to safe code and do not force a step-down.

## Enforcement

Set lints to `warn`; make the gate hard in hooks/CI with `cargo clippy --workspace --all-targets -- -D warnings`. Pin the toolchain — a newer clippy's added lints break `-D warnings`. Good pre-commit checks (tool-agnostic — githooks, etc.):

- `cargo fmt --all --check`
- `cargo clippy --workspace --all-targets -- -D warnings`
- `cargo workspace-lints`
