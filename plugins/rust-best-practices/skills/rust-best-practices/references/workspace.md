# Workspaces

How a Cargo workspace shares configuration across member crates. The shape is uniform for all three tables below: declare once in the root `Cargo.toml`, opt in from each member with `<thing>.workspace = true`. Cargo never applies workspace config to a member that does not opt in — a scaffolded crate that forgets silently falls back to the default (unlinted, or a drifting dependency version). Requires Cargo 1.64+ (lint inheritance 1.74+).

## Package metadata — `[workspace.package]`

Shared package fields (version, edition, rust-version, license, authors, repository, …) declared once, inherited per field.

```toml
# root Cargo.toml
[workspace.package]
version = "0.1.0"
edition = "2024"
rust-version = "1.96"
license = "GPL-3.0-only"
```
```toml
# member Cargo.toml
[package]
name = "my-crate"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true
```

## Lints — `[workspace.lints]`

Declare the lint config once at the root (the recommended set lives in `lint-setup.md`); every member must opt in:

```toml
# member Cargo.toml
[lints]
workspace = true
```

A crate missing this line silently escapes every workspace lint — a real hazard when a new crate is scaffolded. Guard it with [`cargo-workspace-lints`](https://github.com/JarredAllen/cargo-workspace-lints), which fails if any member lacks the inheritance.

## Dependencies — `[workspace.dependencies]`

One version per dependency, defined once at the root. A version declared separately in each member drifts: bump one crate, forget another, and if the two land on semver-incompatible ranges Cargo resolves *both* copies into the tree. That bloats builds, and for derive/reflection crates (facet, serde) it breaks trait identity — a `T: Facet` from facet 0.46 is a different trait than from 0.47, so values silently won't cross the crate boundary.

```toml
# root Cargo.toml
[workspace.dependencies]
jiff = "0.2"
facet = "0.46"
regex = { version = "1", default-features = false, features = ["std"] }
```
```toml
# member Cargo.toml — inherit, then add features as needed
[dependencies]
jiff.workspace = true
facet = { workspace = true, features = ["jiff02"] }
```

### What a member may override

Only `features` and `optional`. Version and `default-features` live at the root.

| At the member | Verdict |
|---|---|
| `dep.workspace = true` | ✅ inherit as-is |
| `{ workspace = true, features = [...] }` | ✅ features are ADDITIVE — unioned with the root set, never subtracted |
| `{ workspace = true, optional = true }` | ✅ `optional` must be set here — the root table cannot declare it |
| `{ workspace = true, version = "…" }` | ❌ version is the root's job |
| `{ workspace = true, default-features = false }` | ❌ hard error on edition 2024 unless the root also set `default-features = false` |

### The `default-features` gotcha

Feature resolution is workspace-wide: if any member enables a dependency's default features, every member building that dependency gets them. A member therefore cannot unilaterally turn defaults off. To make defaults opt-in, set `default-features = false` at the root; members that need them add the specific features back. Edition 2024 makes the mismatch a hard error; earlier editions silently ignored the member's `default-features = false`.

### What to hoist

- **External dep used by 2+ members** — always hoist; this is where drift bites.
- **Single-use external dep** — hoisting is optional but still keeps every version in one file.
- **Internal path deps** (`finances-model = { path = "…" }`) — leave as path deps; they carry no external version to drift.

## Enforcement

- **Lints:** `cargo-workspace-lints` fails if a member lacks `[lints] workspace = true`.
- **Dependencies:** Cargo has no built-in "should be inherited" lint (clippy #10306 is open). `wildcard_dependencies = "warn"` (see `lint-setup.md`) blocks `"*"` versions. To migrate or audit, `cargo-autoinherit` hoists shared deps and `cargo-workspace-inheritance-check` flags members that pin versions directly.

## STOP — anti-rationalization

| Rationalization | Reality |
|---|---|
| "Only this crate uses it — declare the dep locally" | Fine today; the second user is where drift starts, and it's silent. Hoisting now costs nothing. |
| "I'll just keep the versions matched by hand" | Hand-matched versions are the drift — they diverge on the next bump nobody mirrors. One source of truth. |
| "Different crates can pin different versions" | Semver-compatible ranges unify to one copy anyway; incompatible ones duplicate in the tree — a footgun, not a feature. Explicit divergence needs a real reason (migration in flight), not convenience. |
| "New crate builds fine without `[lints] workspace = true`" | It compiles because it's silently unlinted. Add the inheritance line to every member. |
