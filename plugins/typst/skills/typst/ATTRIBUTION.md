# Attribution

The `typst` skill in this directory is vendored **whole** from:

- **Upstream:** https://github.com/lucifer1004/claude-skill-typst
- **Commit:** `94b0c65944e743b3389d24a1c99736bf92605c72`
- **License:** MIT — Copyright (c) 2026 lucifer1004 (see [`LICENSE`](./LICENSE))

It is redistributed here under the terms of the MIT License, with the license text
and copyright notice retained in `LICENSE`.

## What was changed

The skill content (`SKILL.md`, reference `*.md`, `examples/`, `scripts/`, `agents/`,
and the `data/` index files) is copied verbatim. The only additions are this file and
the regeneration tooling under [`../../tools/`](../../tools/), which lets this vendored
copy refresh its `data/` indexes instead of going stale. See
[`../../tools/README.md`](../../tools/README.md).

## Keeping it in sync

The `data/` indexes (Typst API dumps + BM25 search indexes + Typst Universe package
index) are refreshed automatically by the repository workflows
`.github/workflows/update-typst-packages.yml` and `update-typst-api.yml`, which run the
vendored tools weekly — the same cadence and mechanism as upstream.
