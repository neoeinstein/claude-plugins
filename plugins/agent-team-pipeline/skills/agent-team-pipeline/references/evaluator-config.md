# Evaluator Configuration

Projects customize the pipeline's review phase by placing evaluator definitions in `.claude/pipeline-evaluators/`. Each evaluator is a markdown file with frontmatter — the same pattern used for agent definitions.

## Directory Structure

```
.claude/pipeline-evaluators/
  config.md                # pipeline-level settings (language, base branch, built-in overrides)
  pii-privacy.md           # custom evaluator
  htmx-patterns.md         # custom evaluator
  domain-invariants.md     # custom evaluator
```

## Pipeline Config

`.claude/pipeline-evaluators/config.md` controls pipeline-level settings and built-in evaluator overrides.

```markdown
---
language: rust
base_branch: main
packs:
  - ~/.claude/evaluator-packs/redis-pack
  - ~/.claude/evaluator-packs/aws-documentdb-pack
---

# Pipeline Configuration

## Built-in Evaluator Overrides

### code-quality
- **gate**: zero-issues

### type-safety
- **gate**: zero-issues

### security
- **enabled**: false
```

**Fields:**
- `language` — resolves language-specific hints in built-in evaluators
- `base_branch` — target branch for merge operations (default: main)
- `packs` — list of paths to shared evaluator pack directories (see Evaluator Packs below)
- Built-in evaluators are listed by name with override values under headings

## Custom Evaluator Format

Each custom evaluator is a standalone `.md` file. The prompt is the document body.

```markdown
---
name: pii-privacy
model: sonnet
gate: zero-issues
---

Review the diff for PII exposure risks:

1. Are email addresses, names, or other PII passed to logging frameworks?
2. Are PII types accidentally exposed via Display/ToString/format?
3. Do error messages include raw PII instead of redacted forms?
4. Is PII stored in plain text where it should be hashed or encrypted?

For each issue:
- File:line reference
- What PII is exposed
- Severity: Critical / Important / Minor
- Fix: specific remediation

## Language Hints

### Rust
Check Display impls, tracing::info!/warn!/error! macro arguments,
format!() calls, and Askama template variable usage for PII leaks.
Email types should use .redacted() for logging, never .as_str() or Display.

### TypeScript
Check console.log/warn/error arguments, template literal interpolation,
JSON.stringify of user objects, and error message construction.
```

### Frontmatter Fields

| Field | Required | Values | Default |
|-------|----------|--------|---------|
| `name` | yes | identifier (kebab-case) | — |
| `model` | no | `haiku`, `sonnet`, `opus` | `sonnet` |
| `gate` | no | `zero-issues`, `advisory` | `zero-issues` |

### Document Body

The document body is the evaluator prompt — it is passed directly to the evaluator agent as its review instructions.

### Language Hints Section

If the document contains a `## Language Hints` section with language-specific subsections (`### Rust`, `### TypeScript`, etc.), the orchestrator appends the matching subsection to the prompt based on the pipeline's `language` setting.

## How Evaluators Are Dispatched

The orchestrator reads `.claude/pipeline-evaluators/` and dispatches evaluators in Phase 6:

1. **Built-in evaluators** use the `agent-team-pipeline:evaluator` agent with pre-defined prompts. The pipeline config's `language` setting selects the appropriate built-in language hints.

2. **Custom evaluators** use the `agent-team-pipeline:evaluator` agent with the `.md` file's body as the evaluation prompt. Language hints are appended if the pipeline language matches a subsection.

3. **Gate modes**:
   - `zero-issues` — any findings block the pipeline. The orchestrator must dispatch a fixer and re-run.
   - `advisory` — findings are reported but don't block. Useful for style or framework-specific checks.

4. **Parallel dispatch**: All evaluators run in parallel. The orchestrator waits for all to complete before presenting consolidated results.

## Default Behavior (No Config Directory)

If no `.claude/pipeline-evaluators/` directory exists, the pipeline runs with:
- `code-quality`: enabled, zero-issues gate
- `type-safety`: enabled, zero-issues gate (no language hints)
- `security`: enabled, zero-issues gate

## Evaluator Packs

Packs are shared directories of evaluator `.md` files — same format as project evaluators. They allow domain knowledge (Redis gotchas, DocumentDB vs MongoDB differences, framework patterns) to be reused across projects.

### Pack Structure

A pack is a directory of `.md` evaluator files:
```
~/.claude/evaluator-packs/redis-pack/
  connection-pooling.md
  key-expiry-patterns.md
  hot-key-detection.md
```

### How Packs Are Loaded

1. The orchestrator reads `packs` from `config.md` frontmatter
2. Each path is resolved and its `.md` files are loaded as evaluators
3. Pack evaluators merge with local evaluators — **local wins on name collision**
4. All evaluators (local + pack) are dispatched in parallel in Phase 6

### Where Packs Live

Packs are just directories on the filesystem. Common locations:
- `~/.claude/evaluator-packs/` — user-level, shared across all projects
- A shared team repo checked out locally
- A monorepo's `shared/evaluator-packs/` directory

No registry or package manager — packs evolve by editing markdown files.

## Evaluator Template

Use the pii-privacy example above as a starting template for new evaluators.
