# Parallel Pipelines and Task De-conflicting

When a plan contains multiple independent tasks, the orchestrator can dispatch them in parallel. This document covers the rules for safe parallel execution.

## Task Dependency Graph

The planner outputs tasks with explicit dependency edges:

```
Task A (no deps)  ──→ Task C (depends on A, B)  ──→ Final verification
Task B (no deps)  ──→ Task C
                      Task D (depends on A)      ──→ Final verification
```

**Rules:**
- Tasks with no unresolved dependencies can run in parallel
- A task cannot start until all its dependencies are complete
- The orchestrator must verify dependency completion before dispatching

## Worktree Isolation

Each mutating agent gets its own worktree via `isolation: "worktree"` on the Task tool.

**Why worktrees, not branches:**
- Worktrees provide filesystem-level isolation — agents can't accidentally modify each other's files
- The Task tool manages worktree lifecycle automatically
- Failed agents leave no artifacts in the main working tree

**Merge coordination:**
- Independent tasks that touch different files: merge in dependency order, fast-forward when possible
- Independent tasks that touch the same files: merge the first, then rebase/re-run the second
- The orchestrator checks for conflicts before merging

## De-conflicting Strategy

When parallel tasks modify overlapping files:

1. **Detect early** — the planner should identify file overlaps in the task graph
2. **Serialize overlapping tasks** — add a dependency edge between tasks that touch the same files
3. **If discovered during merge** — the second task's worktree needs rebasing and re-verification

**The planner is responsible for minimizing conflicts.** Group changes by file scope, not by conceptual similarity. A task that touches `error.rs` and a task that touches `error.rs` should be sequenced, even if they're conceptually independent.

## Orchestrator Checklist for Parallel Dispatch

Before dispatching parallel tasks:
- [ ] All dependency edges resolved (no pending prerequisites)
- [ ] No two parallel tasks modify the same file (or they're explicitly sequenced)
- [ ] Each task has a clear scope boundary
- [ ] Verification commands specified for each task independently

After parallel tasks complete:
- [ ] Verify each task's build/test gate independently
- [ ] Merge in dependency order
- [ ] Run full verification after all merges complete
- [ ] If merge conflict: re-dispatch the conflicting task with updated base

## When NOT to Parallelize

- Tasks that modify the same type signature or API surface
- Tasks where the second task's correctness depends on the first task's output
- When the plan has fewer than 3 tasks (overhead exceeds benefit)
- When the user prefers sequential execution (ask if unclear)

## Investigation Decomposition for Heavy Pipelines

When a codebase is large enough that a single investigator would be slow or miss patterns, dispatch multiple investigators in parallel. Split by **search strategy**, not by file or crate scope:

- **Pattern investigator** — searches for usages of the target pattern (call sites, type references, trait impls)
- **Construction investigator** — searches for where the relevant types or structs are built or initialized
- **Cross-reference investigator** — searches for related concepts (tests, adjacent types, doc comments, integration points)

Each investigator should have a distinct search methodology so results are complementary rather than redundant. The orchestrator merges and de-duplicates findings before handing off to the planner.

**Heuristic:** Use multiple investigators when the investigation requires more than ~5 distinct search queries or spans more than ~3 crates.

## Worktree Branching for Dependent Tasks

When dispatching a task that depends on a completed task, the worktree is created from the branch state **after** the dependency's changes have been merged. This ensures the dependent task sees the correct base and does not re-introduce or conflict with already-landed work.

The orchestrator must merge each dependency's branch before creating the next task's worktree — do not create downstream worktrees speculatively from an unmerged base.
