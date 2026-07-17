#!/bin/bash
# PostToolUse hook: Format Rust files with rustfmt after writes.
#
# Toolchain selection, in order of preference:
#   1. Repo-local mise pin: the repo pins `rust` in its own mise config (the pin
#      resolves from a config at/above the file). Format via `mise exec` so the
#      hook matches the toolchain the repo's mise-driven gates/CI use, rather
#      than whatever rustfmt is first on PATH.
#   2. rust-toolchain.toml / rust-toolchain: the repo's canonical, tool-agnostic
#      pin. Defer to it (plain rustfmt with RUSTUP_TOOLCHAIN unset so rustup
#      reads the file) rather than override it with a user-global mise pin.
#   3. Global mise pin: mise pins `rust` only via user-global config. Format via
#      `mise exec` (the user's default toolchain).
#   4. Plain rustfmt from PATH: nightly when a rustfmt.toml/.rustfmt.toml exists
#      (for nightly-only options), stable otherwise.
#
# Regardless of which toolchain is chosen, the edition is resolved from
# Cargo.toml and passed as `--edition` (see crate_edition): a bare `rustfmt
# <file>` defaults to edition 2015, so without this it would silently disagree
# with `cargo fmt` (which passes the crate's real edition) on import sort order
# and layout.
#
# Why route through mise at all: `mise exec` sets RUSTUP_TOOLCHAIN to the pin and
# prepends its rust bin, so it wins over a stale RUSTUP_TOOLCHAIN in the
# environment, a stale PATH entry, rust-toolchain.toml, and the rustup default.
#
# This script is designed to be fail-open: it should never block edits.
# We intentionally avoid `set -e` so that any unexpected failure
# falls through to exit 0 rather than blocking the edit operation.

# Extract file path from hook input (JSON on stdin)
file_path=$(jq -r '.tool_input.file_path' 2>/dev/null || echo "")

if [ -z "$file_path" ]; then
  exit 0
fi

# Only format Rust files
if [[ "$file_path" != *.rs ]]; then
  exit 0
fi

# Resolve to an absolute path so a mise/rustup directory change can't strand it.
case "$file_path" in
  /*) ;;
  *) file_path="$PWD/$file_path" ;;
esac
file_dir=$(dirname "$file_path")

# Walk up from the file's directory; succeed if any named file exists in an
# ancestor (used for rust-toolchain.toml and rustfmt.toml discovery).
find_up() {
  local dir="$file_dir" name
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    for name in "$@"; do
      if [ -e "$dir/$name" ]; then
        return 0
      fi
    done
    dir=$(dirname "$dir")
  done
  return 1
}

# Resolve the Rust edition the way `cargo fmt` does, and pass it to rustfmt.
# A bare `rustfmt <file>` (which is what every tier below runs) does NOT read
# Cargo.toml and defaults to edition 2015, while `cargo fmt` passes the crate's
# real edition. The two style editions sort imports and lay out code
# differently, so without this the hook silently fights `cargo fmt`.
#
# Walk up from the file and take the first literal `edition = "NNNN"`. A member
# that inherits via `edition.workspace = true` has no literal, so the walk
# continues to the workspace-root Cargo.toml where the literal lives.
crate_edition() {
  local dir="$file_dir" line
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/Cargo.toml" ]; then
      line=$(grep -m1 -E '^[[:space:]]*edition[[:space:]]*=[[:space:]]*"[0-9]+"' "$dir/Cargo.toml" 2>/dev/null)
      if [ -n "$line" ]; then
        printf '%s' "$line" | sed -E 's/.*"([0-9]+)".*/\1/'
        return 0
      fi
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

# Built once and expanded into every rustfmt call below. Empty (no `--edition`)
# when no Cargo.toml edition is found, preserving the prior default behavior.
edition_args=()
edition=$(crate_edition)
if [ -n "$edition" ]; then
  edition_args=(--edition "$edition")
fi

# Discover a mise-managed, active, installed `rust` tool for this directory, and
# where it is pinned. Gate on `mise ls --current`, NOT `mise which rustfmt`:
# `mise which` falls back to PATH when mise manages nothing, so it succeeds even
# with no pin. `--installed` guarantees no network install is triggered here.
mise_rust_source=""
if command -v mise &>/dev/null; then
  mise_rust_source=$(mise -C "$file_dir" ls --current --installed rust --json 2>/dev/null \
    | jq -r 'map(select(.installed and .active)) | .[0].source.path // empty' 2>/dev/null)
fi

# A pin is repo-local when its config lives at or above the file's directory;
# the user-global config (~/.config/mise) is not an ancestor of a repo file.
mise_rust_repo_local=false
if [ -n "$mise_rust_source" ]; then
  src_dir=$(dirname "$mise_rust_source")
  case "$file_dir/" in
    "$src_dir"/*) mise_rust_repo_local=true ;;
  esac
fi

# Format via mise, letting it fail open rather than reformatting with a
# mismatched PATH rustfmt.
format_with_mise() {
  mise -C "$file_dir" exec -- rustfmt "${edition_args[@]}" "$file_path" 2>/dev/null
  exit 0
}

# 1. Repo-local mise pin wins: the repo opted into mise for rust.
if [ -n "$mise_rust_source" ] && [ "$mise_rust_repo_local" = true ]; then
  format_with_mise
fi

# 2. rust-toolchain.toml is the repo's canonical pin: defer to it over a global
#    mise pin. Unset any (possibly stale) RUSTUP_TOOLCHAIN so rustup resolves the
#    toolchain from the file; cd so the file is found relative to its own tree.
if find_up rust-toolchain.toml rust-toolchain; then
  if command -v rustfmt &>/dev/null; then
    ( cd "$file_dir" && env -u RUSTUP_TOOLCHAIN rustfmt "${edition_args[@]}" "$file_path" ) 2>/dev/null || exit 0
  fi
  exit 0
fi

# 3. Global mise pin: no repo-local rust pin of any kind.
if [ -n "$mise_rust_source" ]; then
  format_with_mise
fi

# 4. No mise-managed rust anywhere: plain rustfmt from PATH.
if ! command -v rustfmt &>/dev/null; then
  exit 0
fi

if find_up rustfmt.toml .rustfmt.toml; then
  # Config found: try nightly (for nightly-only options), fall back to stable
  rustfmt +nightly "${edition_args[@]}" "$file_path" 2>/dev/null || rustfmt "${edition_args[@]}" "$file_path" 2>/dev/null || exit 0
else
  # No config: use stable directly
  rustfmt "${edition_args[@]}" "$file_path" 2>/dev/null || exit 0
fi
