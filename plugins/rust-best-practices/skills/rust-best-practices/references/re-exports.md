# Re-exports and Public Paths

Where public items live: `pub use` policy, facades, root promotion, preludes. For organizing pure logic vs I/O, see `fcis.md`.

## The canonical-path rule

Every public item gets exactly ONE public path — where it is defined (or facaded), documented, and imported. rustdoc cannot mark a canonical location (the proposed `#[doc(canonical)]` remains an open RFC), so with multiple public paths: search dedupes and tends to display the shallowest path (misstating provenance), docs duplicate or fragment, and each path is independent semver surface.

## Flatten with a facade, not aliases

Keep implementation in private submodules; `pub use` each item at its one public home. When the source module is private, rustdoc inlines the docs at the re-export site automatically — no attributes needed.

```rust
// sync/mod.rs
mod mutex;                          // private implementation
pub use mutex::{Mutex, MutexGuard}; // ONE public path: crate::sync::Mutex
```

This is tokio's shape: `mutex.rs`/`rwlock.rs` are private; every item surfaces exactly once at `tokio::sync`.

## Root promotion — the only sanctioned second path

Re-export at the crate root only items nearly every user must name (serde: its four core traits; tokio: only `task::spawn`). Test: would it be comparatively rare for a client to write this path? Then don't promote.

- Ceiling is TWO paths: canonical module + crate root. Mark the root re-export `#[doc(inline)]` so the root becomes the primary documented location.
- Intermediate ancestors are never re-export sites (`a::b` and `a::b::c` both exposing `d`): each extra hop multiplies the harms above, and no major crate does it.

## Verdict table

| Re-export | Verdict |
|---|---|
| Private module → its public parent (facade) | ✅ the default flattening tool |
| Marquee items → crate root with `#[doc(inline)]` | ✅ deliberate, tiny set |
| `pub(crate) use` / private internal facades | ✅ zero public surface |
| Curated, documented prelude module | ✅ alias set — every item keeps its canonical home |
| Same item exposed at multiple ancestor levels | ❌ one home; delete the extra paths |
| `pub use foo::*` across module/crate boundaries | ❌ enumerate individually — globs silently export whatever is added later and can't be audited in review |
| `pub use dependency::Type` | ⚠️ deliberate API commitment only — couples your semver to theirs, and rustdoc renders cross-crate re-exports poorly |

## Domain depth is not a defect

Paths that mirror domain structure are good API: `tokio::sync::mpsc::Sender` lives two levels down and is documented there. Flattening for import convenience is what preludes are for — not ancestor re-exports.

## STOP — anti-rationalization

| Rationalization | Reality |
|---|---|
| "Re-export here too for discoverability" | Extra paths reduce discoverability: search picks one arbitrarily, docs fragment. One home IS discoverability. |
| "Users shouldn't need to know the module tree" | Promote to the root (if marquee) or a prelude — never to every ancestor. |
| "Glob re-export tracks the submodule automatically" | That's the hazard: future items export silently. Enumerate. |
| "It's just an alias, no cost" | Every public path is semver surface and a provenance claim. |
