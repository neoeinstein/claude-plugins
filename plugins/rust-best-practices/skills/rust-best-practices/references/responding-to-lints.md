# Responding to Lints

Fix-time authority: a lint fired and you're deciding what to do. For the recommended config, per-crate inheritance, and the unsafe ladder, see `lint-setup.md`.

## Fix first

The default response to any lint is to fix the code, not silence it.

1. **Fix the code** — the right answer almost every time. `collapsible_if` → collapse it; `manual_let_else` → use `let ... else`; `needless_return` → drop the `return`.
2. **Restructure** — `too_many_arguments`, `cognitive_complexity`, and friends point at a design issue. The fix is refactoring, not suppression.
3. **Suppress only for a structural constraint you cannot change** — a framework signature, a verified false positive, or a temporary WIP marker.

## When suppression IS justified

| Justification | Example reason |
|---|---|
| Framework signature | `"axum handler signature requires owned types"` |
| Verified false positive | `"inner field is not mutated after insertion"` |
| Recurring idiomatic case | `"tests"` |
| WIP marker (temporary) | `"wiring up in the register_routes commit"` |

## When suppression is NOT justified

- "It's just a style lint" / "more readable this way" — the idiomatic form is less *familiar*, not less readable. Fix it.
- "I don't want to restructure" — if the lint flags a real design issue, restructuring IS the fix.
- "I'll fix it later" — the fix is almost always smaller than the suppression annotation. Do it now.

## STOP — anti-rationalization

| Rationalization | Reality |
|---|---|
| "I'll suppress and fix later" | You won't. The fix is smaller than the annotation. |
| "The idiomatic form is less readable" | Less familiar, not less readable. Learn the idiom. |
| "It's just cosmetic" | Cosmetic lints have cosmetic fixes. |
| "The suggestion changes behavior" | Verify. If truly a false positive, suppress with a reason naming the semantic difference. |

## `expect`, never `allow` (in source)

`allow` levels appear ONLY in `Cargo.toml` (`[workspace.lints]`). Source code uses ONLY `#[expect(lint, reason = "…")]` — self-cleaning (warns when stale) and reviewable. The `allow_attributes` + `allow_attributes_without_reason` lints (see `lint-setup.md`) make this mechanical.

| Suppression | Verdict |
|---|---|
| `X = "allow"` in `Cargo.toml` | ✅ the only place a bare allow belongs |
| `#[expect(clippy::X, reason = "…")]` in source | ✅ justified, per-instance |
| `#[allow(clippy::X)]` in source | ❌ rejected by `allow_attributes` |
| `#[expect(clippy::X)]` with no reason | ❌ rejected by `allow_attributes_without_reason` |

Reason length follows the case: a recurring idiomatic suppression takes a terse reason (`"tests"`); a genuine one-off exception takes a specific reason naming the constraint (`"matches DB schema constructor; builder planned for v2"`).

## `dead_code`

`#[expect(dead_code)]` is a WIP marker, not a permanent annotation — it means "not wired up yet; tell me when it is." Zero `dead_code` suppressions should survive to the end of a task.

| Situation | Do |
|---|---|
| Building toward using it | `#[expect(dead_code, reason = "…")]` — temporary |
| Only referenced by tests | It IS dead. Delete it; refactor valuable tests onto live paths |
| Test helper / infrastructure | Move behind `#[cfg(test)]`, not a suppression |
| Tested but not yet called from prod | `#[cfg_attr(not(test), expect(dead_code, reason = "…"))]` — still a WIP marker |
| End of task/PR | Wire it up or delete it — none should remain |

Never prefix a Serde field with `_` to silence `dead_code`: it changes the expected key. Delete the field or use `#[expect(dead_code, reason = "…")]`. See `serde.md` § Dead Fields.

### `dead_code` anti-rationalization

| Rationalization | Reality |
|---|---|
| "Conditionally dead — used in tests" | If ONLY tests call it, it IS dead. Delete, or move test infra behind `#[cfg(test)]`. |
| "I'll use it later" | `expect(dead_code)` is mid-task only. Remove before completing. |
| "I used `cfg_attr`, not `allow`" | More precise WIP marker, same end-of-task rule: wire up or delete. |
| "The reason is obvious" | If obvious, it's cheap to write. Reasons make suppressions reviewable. |
