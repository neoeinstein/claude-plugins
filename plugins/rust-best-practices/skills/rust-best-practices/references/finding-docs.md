# Finding Documentation

Unsure how to use a crate, or need a specific item's signature or behavior.

## Primary: docs.rs — the specific item page

Fetch the **item or module page**, not the crate root: `https://docs.rs/tokio/latest/tokio/task/struct.JoinSet.html`, not `https://docs.rs/tokio`. The item page carries the signature, trait impls, and examples; the root just makes you hunt.

## Targeted / programmatic lookup: rustdoc JSON

docs.rs serves rustdoc JSON at `https://docs.rs/crate/{name}/latest/json` (zstd-compressed; format documented at `https://docs.rs/about/rustdoc-json`).

**Never read the raw JSON into context** — a mid-size crate decompresses to ~3MB and will blow your context window. Download and query locally for the one item you need:

```bash
curl -sL https://docs.rs/crate/serde/latest/json | zstd -d | \
  jq '.index[] | select(.name == "Deserializer")'
```

## `cargo doc` for your own crate

Build with `cargo doc` when generated docs help your task, but omit `--open` — it launches a browser window that interrupts the user while you're driving. Reserve `--open` for when the user explicitly wants to view the docs themselves. To read what you built, open the HTML under `target/doc/<crate>/` directly.

`cargo doc` only builds docs for dependencies whose features are enabled. If a dep is behind an optional feature (e.g. `serde`), you need `cargo doc --features serde` or `cargo doc --all-features` for its docs to appear at all.
