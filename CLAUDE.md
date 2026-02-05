# neoeinstein-plugins

Last verified: 2026-02-04

## Purpose

Claude Code plugin marketplace. Hosts development-focused plugins distributed via `.claude-plugin` manifests.

## Project Structure

- `.claude-plugin/marketplace.json` -- Marketplace catalog (plugin registry)
- `plugins/<name>/` -- Individual plugins, each self-contained
- `plugins/<name>/.claude-plugin/plugin.json` -- Per-plugin manifest
- `plugins/<name>/skills/<skill-name>/SKILL.md` -- Skill definitions
- `plugins/<name>/hooks/` -- Hook scripts + `hooks.json` config
- `plugins/<name>/docs/` -- Design notes and future plans
- `docs/design-plans/` -- Implementation design documents

## Conventions

### Plugin Manifest Format

- `marketplace.json` at `.claude-plugin/marketplace.json` with `pluginRoot: "./plugins"`
- Each plugin has `.claude-plugin/plugin.json` with name, version, description, author, keywords
- Domain-only naming (no author prefix): `rust-best-practices`, not `neoeinstein-rust-best-practices`
- Hook commands use `${CLAUDE_PLUGIN_ROOT}` for portable paths
- Skills namespaced as `plugin-name:skill-name`

### Plugin Versioning

- `1.0.0` for production-ready plugins (currently: rust-best-practices)
- `0.1.0` for stubs awaiting full design (currently: askama, htmx-alpine, mise)

### Skill Structure

- SKILL.md frontmatter: `name` and `description` fields
- Reference docs loaded lazily via lookup tables in SKILL.md (not force-loaded)
- Anti-rationalization tables (STOP sections) for compliance enforcement

## Invariants

- Every plugin directory must have `.claude-plugin/plugin.json`
- Every plugin listed in `marketplace.json` must have a matching directory under `plugins/`
- Hooks must be fail-open (never block edits on failure)
- Reference docs are standalone -- each can be loaded independently

## Current Plugins

| Plugin | Version | Contents |
|--------|---------|----------|
| rust-best-practices | 1.0.0 | Skill + 15 reference docs + rustfmt hook |
| askama | 0.1.0 | 2 migrated skills, design notes |
| htmx-alpine | 0.1.0 | 1 stub skill, design notes |
| mise | 0.1.0 | 1 stub skill, design notes |
