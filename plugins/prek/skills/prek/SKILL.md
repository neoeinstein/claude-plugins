---
name: prek
description: Use when setting up git pre-commit hooks with prek - writing .pre-commit-config.yaml, installing or running hooks, wiring repo-local checks (fmt, lint, tests), or migrating from Python pre-commit. prek is a fast, single-binary, pre-commit-compatible runner (no Python required).
---

# prek: pre-commit hooks

prek ([github.com/j178/prek](https://github.com/j178/prek)) reads the same
`.pre-commit-config.yaml` as Python `pre-commit` — existing configs work
unchanged. Migration is: install prek, run `prek install`.

## Install

| Via | How |
|---|---|
| mise (preferred) | `prek = "latest"` under `[tools]` (registry: `aqua:j178/prek`) |
| Homebrew | `brew install prek` |
| cargo | `cargo install prek` |

## Repo-local hooks (the common case)

Repo-local toolchain commands use `repo: local` + `language: system`:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: fmt
        name: cargo fmt (check)
        entry: cargo fmt --all --check
        language: system
        types: [rust]
        pass_filenames: false
      - id: clippy
        name: cargo clippy (-D warnings)
        entry: cargo clippy --workspace --all-targets -- -D warnings
        language: system
        types: [rust]
        pass_filenames: false
      - id: workspace-lints
        name: cargo workspace-lints
        entry: cargo workspace-lints
        language: system
        files: (^|/)Cargo\.toml$
        pass_filenames: false
```

Remote-repo hooks work as in pre-commit; pin `rev:` to a tag.

## Activate and run

```bash
prek install            # write the git hook (once per clone)
prek run --all-files    # run every hook against the whole tree (CI / first run)
```

Offer a repo task so clones activate consistently, e.g. mise:
`[tasks.hooks] run = "prek install"`.

## Rules

- `pass_filenames: false` for whole-workspace commands (cargo, tsc, …) —
  otherwise the hook receives the staged file list as arguments.
- Scope manifest-only hooks with `files:` (regex) instead of `types:`.
- `language: system` runs commands from the committer's PATH — toolchain
  managers (mise, rustup) must be active in the git environment.
- Hooks see staged files only; use `prek run --all-files` in CI to gate the
  full tree.
