# Lessons from Practice

These lessons are drawn from real pipeline sessions and use language-specific examples (Rust) for concreteness. The underlying principles are language-agnostic and apply to any pipeline.

## Lesson 1: Validators Must Independently Verify Factual Claims

**What happened:** A planner claimed `worker::Error` doesn't implement `std::error::Error`. The plan-validator rubber-stamped this claim without reading the source. The entire plan was built on a false premise.

**Principle:** Plan validators must read the actual source code to verify claims — not trust the planner's assertions. If the planner says "type X doesn't implement trait Y," the validator must check.

**Prevention:** The plan-validator agent definition explicitly requires independent verification of all factual claims.

## Lesson 2: Users Catch What Automated Gates Miss

**What happened:** The validator approved a plan based on the false `worker::Error` claim. The user challenged: "Does String make sense there? Or should we be wrapping the worker error?" — which led to reading the actual source and discovering the claim was wrong.

**Principle:** Automated gates are necessary but not sufficient. Human review of plans catches domain-knowledge errors that validators miss.

**Prevention:** Always present plans to the user for review. Don't skip human gates even when automated validation passes.

## Lesson 3: Investigation Completeness Determines Plan Quality

**What happened:** An initial investigation found 6 construction sites for a `Database` error variant. The corrected plan found 13. The original investigator stopped searching too early.

**Principle:** Incomplete investigation → incomplete plan → missed changes → broken build. The investigator must be exhaustive.

**Prevention:** The investigator agent definition emphasizes exhaustive search with multiple strategies and completeness checks.

## Lesson 4: SyncFailed vs RefreshFailed — Same Wrapper, Different Semantics

**What happened:** Two error variants both wrapped string messages, but `SyncFailed` wraps HTTP status descriptions (`"returned status 404"`) while `RefreshFailed` wraps actual `worker::Error` values. The plan correctly kept `SyncFailed(String)` while converting `RefreshFailed` to typed wrapping.

**Principle:** Not all string-wrapped errors are the same. Verify what each construction site actually wraps before deciding how to type it.

**Prevention:** Investigation must classify each construction site's actual value source, not just its error variant.

## Lesson 5: Fresh Agent Per Task Prevents Context Drift

**What happened:** Across multiple pipeline sessions, agents that accumulated context from earlier phases started making assumptions instead of reading code. Fresh agents per task consistently produced more accurate results.

**Principle:** Context accumulation leads to assumption-based work. Fresh agents verify from scratch.

**Prevention:** Always dispatch fresh agents for each phase. Never reuse an investigation agent for planning.

## Lesson 6: Agents May Complete Without Sending Summary Messages

**What happened:** An implementor committed its changes and went idle without sending a completion message. The orchestrator stalled waiting for a report that never came.

**Principle:** Agent silence doesn't mean failure. Check `git log --oneline -3` to verify whether work was committed.

**Prevention:** The implementor agent definition explicitly requires a completion message. The orchestrator protocol includes a "check git state on silence" step.

## Lesson 7: Spec Compliance Catches What Code Review Misses (and Vice Versa)

**What happened:** A spec compliance review verified all planned changes were implemented. Separately, the user caught that the `Worker(#[from] worker::Error)` variant created an ambiguous `From` impl — a code quality issue the spec reviewer correctly didn't flag (it wasn't in the spec).

**Principle:** Spec compliance and code quality are orthogonal concerns. Spec says "did we do what we planned?" Code quality says "is what we did well-built?" Both are needed.

**Prevention:** Two-stage review is mandatory: spec compliance (Phase 5) then evaluators (Phase 6).

## Lesson 8: `#[from]` Exclusivity [Rust-specific]

**What happened:** An error enum had `RefreshFailed(#[source] worker::Error)` + `Worker(#[from] worker::Error)`. The `#[from]` generates a `From<worker::Error>` impl that always routes to `Worker`, silently bypassing `RefreshFailed` when `?` is used.

**Principle (generalized):** Automatic error conversion attributes can silently route errors to the wrong variant when multiple variants hold the same inner type. Use explicit construction instead.

**Language-specific manifestations:**
- **Rust**: `#[from]` in thiserror should only exist on a variant when its inner type appears in exactly ONE variant
- **TypeScript**: Multiple `catch` clauses with the same error type create similar routing ambiguity
- **Python**: Multiple `except` clauses catching the same exception type — only the first matches

**Prevention:** The type-safety evaluator's Rust language hints include this check.
