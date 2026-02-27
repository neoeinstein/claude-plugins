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
- `language` — used for skill discovery (see Best-Practice Skill Discovery below)
- `base_branch` — target branch for merge operations (default: main)
- `packs` — list of paths to shared evaluator pack directories (see Evaluator Packs below)
- Built-in evaluators are listed by name with override values under headings

## Custom Evaluator Format

Each custom evaluator is a standalone `.md` file. The prompt is the document body. Evaluators should focus on their specific concern (PII, security, domain invariants) and stay language-agnostic — language-specific best practices come from skills, not evaluator definitions.

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
```

### Frontmatter Fields

| Field | Required | Values | Default |
|-------|----------|--------|---------|
| `name` | yes | identifier (kebab-case) | — |
| `model` | no | `haiku`, `sonnet`, `opus` | `sonnet` |
| `gate` | no | `zero-issues`, `advisory` | `zero-issues` |

### Document Body

The document body is the evaluator prompt — it is passed directly to the evaluator agent as its review instructions.

## Best-Practice Skill Discovery

The pipeline auto-discovers installed skills that provide best practices relevant to the project. No special conventions are required from skill authors — relevance is judged from skill names and descriptions.

### How discovery works

1. During onboarding, the orchestrator dispatches a **haiku agent** with the project's language, domain, and goal
2. The agent scans the available skills list (names and descriptions) and returns a ranked shortlist of relevant skills
3. The orchestrator presents the shortlist to the user, who can add or remove entries
4. The confirmed skill names are passed to downstream agents — **the orchestrator never reads skill content itself**

### Where skills are routed

Each downstream agent loads relevant skills in its own context using the Skill tool:

- **Planner (Phase 2)** — loads relevant skills so plans already reflect idioms and patterns. This is the primary integration point.
- **Evaluators (Phase 6)** — loads relevant skills as review context. Evaluators catch deviations the plan missed. This is the feedback loop.
- **Implementors and fixers do NOT receive skill context** — they follow the plan and fix specific findings. The pipeline's structure is the enforcement mechanism.

### Why evaluators stay language-agnostic

Evaluators define *what to check* (PII exposure, security patterns, domain invariants). Skills define *how to check it in a given language or domain*. Keeping these separate means:
- A PII evaluator works for any language without modification
- Adding a new language means installing a skill, not editing every evaluator
- Evaluator packs stay portable across teams with different tech stacks

## How Evaluators Are Dispatched

The orchestrator reads `.claude/pipeline-evaluators/` and dispatches evaluators in Phase 6:

1. **Built-in evaluators** use the `agent-team-pipeline:evaluator` agent with pre-defined prompts. Best-practice skill context is appended if matching skills are installed.

2. **Custom evaluators** use the `agent-team-pipeline:evaluator` agent with the `.md` file's body as the evaluation prompt.

3. **Gate modes**:
   - `zero-issues` — any findings block the pipeline. The orchestrator must dispatch a fixer and re-run.
   - `advisory` — findings are reported but don't block. Useful for style or framework-specific checks.

4. **Parallel dispatch**: All evaluators run in parallel. The orchestrator waits for all to complete before presenting consolidated results.

## Default Behavior (No Config Directory)

If no `.claude/pipeline-evaluators/` directory exists, the pipeline runs with:
- `code-quality`: enabled, zero-issues gate
- `type-safety`: enabled, zero-issues gate
- `security`: enabled, zero-issues gate

Best-practice skills are still discovered and used even without a config directory.

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

Use the pii-privacy example above as a starting template for new evaluators. Keep evaluators focused on a single concern and language-agnostic — let skills handle language specifics.
