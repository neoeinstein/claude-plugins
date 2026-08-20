#!/bin/bash
# PostToolUse hook: advisory tenet guard for Rust anti-patterns.
#
# Scans ONLY the freshly written code (Edit new_string / Write content), so
# pre-existing patterns elsewhere in a file never nag on unrelated edits.
# Never blocks; on a hit it injects a short additionalContext nudge while
# the edit is still hot. Silent on clean edits — zero token cost.
#
# Families (kept tight to avoid false positives):
#   stringly dispatch — match/matches! on x.as_str()/x.as_deref() (plain
#     path, so `match (method, path.as_str())` routers and FromStr bodies
#     matching a bare `s` do not trip), string-literal comparisons against
#     as_str/as_deref, `let Some("…")`, LIST.contains(&x.as_str()),
#     .map(|s| s == "…"). A `match x.as_str()` whose arms convert INTO a
#     closed type (RHS `Self::V`/`Enum::V`) or match named consts is the
#     boundary converter the advisory already exempts, so it is dropped —
#     the upstream cause (the String field itself) is what stringly_id
#     catches, and that keeps the family covered.
#   error = %e — Display-logging an error field loses the source chain
#   hygiene — #[allow(, serde(untagged), dbg!, fresh unsafe
#   identifier-shaped String — a *field* named id / *_id / *_slug / *_token
#     typed String/Option<String>/Vec<String>; an id deserves a newtype.
#     `let`/`for` bindings share the shape but are not fields, so they are
#     dropped.
#     *_name is deliberately NOT flagged: human/display names are
#     legitimate free text and dominate; machine names acting as
#     identifiers (script_name, event_name) are real but rare, and a
#     stem allowlist fuzzy enough to split them would erode trust in
#     the hook (owner call 2026-08-19)
#
# Placement rule: a pattern belongs here only if the rule AND its remedy
# are repo-free. Repo-owned remedies (project helpers) and runtime-specific
# truths (wasm, DO isolates) belong in that repo's own project hook.

set -euo pipefail

input=$(cat)

file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

if [ -z "$file_path" ] || ! echo "$file_path" | grep -qE '\.rs$'; then
  exit 0
fi

new_code=$(printf '%s' "$input" | jq -r '.tool_input.new_string // .tool_input.content // empty' 2>/dev/null || echo "")

if [ -z "$new_code" ]; then
  exit 0
fi

# Blank out comment lines (preserving line numbers) so prose mentioning a
# pattern never trips the guard.
new_code=$(printf '%s' "$new_code" | sed 's|^[[:space:]]*//.*||')

# Line numbers of `match x.as_str() {` blocks that are true boundary
# converters: every arm either produces a variant of a closed type
# (`=> Self::V` / `=> Enum::V`) or matches a named const, with `_`/binding
# arms neutral. A single literal-to-value arm disqualifies the block, so
# business dispatch still trips.
converter_lines=$(printf '%s' "$new_code" | awk '
{ line[NR] = $0 }
END {
  for (i = 1; i <= NR; i++) {
    if (line[i] !~ /match[ (][A-Za-z_][A-Za-z0-9_.]*\.(as_str|as_deref)\(\)/) continue
    arms = 0; conv = 0; depth = 0
    for (j = i; j <= NR && j <= i + 120; j++) {
      probe = line[j]
      depth += gsub(/\{/, "{", probe) - gsub(/\}/, "}", probe)
      if (j > i && depth <= 0) break
      if (line[j] !~ /=>/) continue
      arms++
      if (line[j] ~ /=>[ ]*(Self|[A-Z][A-Za-z0-9_]*)::[A-Za-z0-9_]/) conv++
      else if (line[j] ~ /^[ \t]*[A-Z][A-Z0-9_]+[ \t]*(\|[ \t]*[A-Z][A-Z0-9_]+[ \t]*)*=>/) conv++
      else if (line[j] ~ /^[ \t]*(_|[a-z_][a-z0-9_]*)[ \t]*=>/) continue
      else { arms = -1; break }
    }
    if (arms > 0 && conv > 0) printf "%s|", i
  }
}' || true)

stringly=$(printf '%s' "$new_code" | grep -nE 'match [A-Za-z_][A-Za-z0-9_.]*\.(as_str|as_deref)\(\)|matches!\([A-Za-z_][A-Za-z0-9_.]*\.(as_str|as_deref)\(\)|\.as_str\(\) *[!=]= *"|\.as_deref\(\) *[!=]= *Some\("|let Some\("|contains\(&[A-Za-z_][A-Za-z0-9_.]*\.as_str\(\)\)|map\(\|[a-z_]+\| *[a-z_]+ *[!=]= *"' \
  | grep -vE "^(${converter_lines}none):" \
  | head -5 || true)

display_err=$(printf '%s' "$new_code" | grep -nE '(error|source_error|cause) *= *%' | head -3 || true)

hygiene=$(printf '%s' "$new_code" | grep -nE '#\[allow\(|serde\(untagged\)|(^|[^a-z_])dbg!\(|unsafe (fn |impl |\{)' | head -3 || true)

stringly_id=$(printf '%s' "$new_code" \
  | grep -nE '(^|[^A-Za-z0-9_])(id|[A-Za-z0-9_]+_(ids?|slugs?|tokens?)): *(Option<|Vec<)?String' \
  | grep -vE '^[0-9]+:[[:space:]]*(let|for|while let|if let)[[:space:]]' \
  | head -3 || true)

msg=""
if [ -n "$stringly" ]; then
  msg="Stringly dispatch:\n${stringly}\nClosed vocab -> enum at the serde/storage boundary; match the enum; each wire token written once (as_str-style). True boundary converters (FromStr body, SQL row edge) are exempt."
fi
if [ -n "$display_err" ]; then
  msg="${msg:+$msg\n\n}Display-logged error loses the source chain:\n${display_err}\nUse error = &e as &dyn std::error::Error. Fine if the value has no Error impl."
fi
if [ -n "$hygiene" ]; then
  msg="${msg:+$msg\n\n}Hygiene:\n${hygiene}\nPrefer #[expect(..)] over #[allow(..)]; never serde(untagged) (write a visitor); no dbg!; new unsafe needs a justification comment (see the skill's unsafe reference)."
fi
if [ -n "$stringly_id" ]; then
  msg="${msg:+$msg\n\n}Identifier-shaped String field:\n${stringly_id}\nIds, slugs, and tokens deserve a domain newtype (aliri_braid or a one-line wrapper) so cross-identifier mixups fail to compile. Storage-row/DTO edge structs mirroring a foreign wire format are the legitimate exception."
fi

if [ -z "$msg" ]; then
  exit 0
fi

jq -n --arg msg "$(printf '%b' "$msg")" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("TENET CHECK (advisory, this edit only):\n" + $msg)
  }
}'
exit 0
