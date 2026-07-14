#!/usr/bin/env bash
# Regenerate the vendored Typst skill index data (../skills/typst/data).
#
# Vendored from lucifer1004/claude-skill-typst (MIT). See ../skills/typst/LICENSE and
# ../skills/typst/ATTRIBUTION.md. The GitHub Actions workflows
# .github/workflows/update-typst-{packages,api}.yml run these same steps weekly.
#
# Usage:
#   ./regenerate.sh                 # refresh the package index (Python 3.10+ + network)
#   ./regenerate.sh --with-api      # ALSO rebuild the main-channel API index
#                                   #   (requires a Rust toolchain + ~2-3 GB to clone/build typst)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data="$here/../skills/typst/data"

echo "==> Refreshing Typst Universe package index"
python3 "$here/fetch-packages.py" --output-dir "$data"

if [[ "${1:-}" == "--with-api" ]]; then
  command -v cargo >/dev/null || { echo "error: --with-api needs a Rust toolchain (cargo)" >&2; exit 1; }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "==> Cloning typst/typst (shallow)"
  git clone --depth 1 https://github.com/typst/typst "$tmp/typst-repo"
  mkdir -p "$tmp/typst-repo/docs/src/bin"
  cp "$here/typst-api-exporter.rs" "$tmp/typst-repo/docs/src/bin/export-api.rs"
  echo "==> Exporting main-channel API entries (cargo build, this is slow)"
  ( cd "$tmp/typst-repo" && cargo run -p typst-docs --bin export-api --release -- --out "$tmp/entries.json" )
  echo "==> Building api-main index + BM25"
  python3 "$here/fetch-api-docs.py" "$tmp/entries.json" \
    --input-format entries --output-stem api-main --out-dir "$data"
fi

echo "==> Done. Review changes under $data"
