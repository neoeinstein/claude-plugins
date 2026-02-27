# agent-team-pipeline Plugin

Last verified: 2026-02-27

## Purpose

Structured multi-agent development pipeline. Orchestrates teams of specialized agents through gated phases: investigate, plan, validate, implement, and two-stage review (spec compliance + pluggable evaluators). Language-agnostic — works for Rust, TypeScript, Python, Go, or any language.

Inspired by OBRA Superpowers (two-stage review, fresh agents per task, skeptical verification) and ED3D patterns (cross-plugin composition, just-in-time loading, project-specific customization).

## Contracts

- **Exposes**: `agent-team-pipeline:orchestrate-pipeline` skill (orchestrator), 7 agent definitions for pipeline roles, SessionStart hook for evaluator config detection
- **Guarantees**: Each phase is independently gated with human checkpoints. Evaluators are pluggable via markdown config. All mutating agents run in worktree isolation. All findings cite file:line references.
- **Expects**: Git repository. No hard dependencies on external plugins — all external plugin references are conditional ("if installed").

## Skill Decomposition

| Skill | Purpose |
|-------|---------|
| `orchestrate-pipeline` | Full 6-phase pipeline coordination (the only skill in this plugin) |

Agent definitions in `agents/` provide role-specific guidance for each pipeline phase (investigator, planner, plan-validator, implementor, spec-reviewer, evaluator, fixer).

## Dependencies

- **Optional**: `ed3d-extending-claude` — pipeline can dispatch project-claude-librarian after completion if installed
- **Boundary**: Language-agnostic core. No hard dependencies on external plugins. Language-specific guidance goes in evaluator `language_hints` configuration.

## Project Customization

Projects configure evaluators via `.claude/pipeline-evaluators/` — a directory of markdown files:
- Each custom evaluator is a `.md` file with frontmatter (name, model, gate) and prompt body
- `config.md` controls pipeline settings (language, base branch, built-in overrides)
- Language hints go in `## Language Hints` sections with per-language subsections
- Follows the same frontmatter+body pattern as agent definitions

## Hooks

- **SessionStart**: Detects `.claude/pipeline-evaluators/` directory and reports available evaluator configuration (language, custom evaluator count/names)

## Key Files

- `skills/agent-team-pipeline/SKILL.md` — Main orchestrator skill
- `skills/agent-team-pipeline/references/` — Evaluator config format, parallel pipelines, lessons
- `agents/` — 7 pipeline role agent definitions
- `hooks/` — SessionStart config detection
