# Typst skill regeneration tools

These scripts rebuild the index data under `../skills/typst/data/` (the Typst API dumps,
their BM25 search indexes, and the Typst Universe package index) that power the vendored
`typst` skill's package/API search.

**Provenance:** vendored from [lucifer1004/claude-skill-typst](https://github.com/lucifer1004/claude-skill-typst)
(MIT). The MIT license text and copyright notice are retained in
[`../skills/typst/LICENSE`](../skills/typst/LICENSE); see
[`../skills/typst/ATTRIBUTION.md`](../skills/typst/ATTRIBUTION.md). `fetch-packages.py`,
`fetch-api-docs.py`, and `typst-api-exporter.rs` are upstream files copied verbatim;
`regenerate.sh` and this README are local additions.

## Files

| File | Role |
| --- | --- |
| `fetch-packages.py` | Fetches `https://packages.typst.org/preview/index.json`, dedupes to latest per package, and builds `packages.json` + `packages-bm25.json`. Needs only Python 3.10+ and network. |
| `fetch-api-docs.py` | Consumes an exported Typst API JSON and builds `api-<ver>.json` + `api-<ver>-bm25.json`. Needs Python 3.10+ (`markdown-it-py`); fetches LaTeX aliases from GitHub (fails soft). |
| `typst-api-exporter.rs` | Rust binary compiled inside a `typst/typst` checkout to export the standard-library API as normalized JSON (only needed for the `main` channel). |
| `regenerate.sh` | Wrapper: package index by default, `--with-api` also rebuilds the `main`-channel API index. |

## Usage

```sh
# Package index only (cheap):
./regenerate.sh

# Also rebuild the main-channel API index (needs Rust + a typst/typst clone):
./regenerate.sh --with-api
```

The stable API snapshots (`api-0.15.0.json`, `api-0.14.2.json`) are pinned; regenerate them
only when a new Typst version ships, by building `typst-docs` at that tag and running
`fetch-api-docs.py` on its output (see upstream's `Justfile` targets
`fetch-api-stable-from-source` / `fetch-api-main-from-source`).

## Automation

`.github/workflows/update-typst-packages.yml` (Mon 06:00 UTC) and
`update-typst-api.yml` (Mon 07:00 UTC) run these weekly and commit any changes — the same
cadence as upstream, so this vendored copy stays fresh instead of rotting.
