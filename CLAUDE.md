# neoeinstein-plugins

Last verified: 2026-02-06

## Purpose

Claude Code plugin marketplace. Hosts development-focused plugins distributed via `.claude-plugin` manifests.

## Project Structure

- `.claude-plugin/marketplace.json` -- Marketplace catalog (plugin registry)
- `plugins/<name>/` -- Individual plugins, each self-contained
- `plugins/<name>/.claude-plugin/plugin.json` -- Per-plugin manifest
- `plugins/<name>/skills/<skill-name>/SKILL.md` -- Skill definitions
- `plugins/<name>/skills/<skill-name>/references/` -- Lazy-loaded reference docs
- `plugins/<name>/hooks/` -- Hook scripts + `hooks.json` config
- `docs/design-plans/` -- Design documents (historical and current)

## Conventions

### Plugin Manifest Format

- `marketplace.json` at `.claude-plugin/marketplace.json` with `pluginRoot: "./plugins"`
- Each plugin has `.claude-plugin/plugin.json` with name, version, description, author, keywords
- Domain-only naming (no author prefix): `rust-best-practices`, not `neoeinstein-rust-best-practices`
- Hook commands use `${CLAUDE_PLUGIN_ROOT}` for portable paths
- Skills namespaced as `plugin-name:skill-name`

### Plugin Versioning

- `1.0.0` for production-ready plugins (currently: rust-best-practices, askama, htmx-alpine, mise)
- `0.1.0` for stubs awaiting full design

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
| askama | 1.0.0 | Skill + 5 reference docs |
| htmx-alpine | 1.0.0 | Skill + 6 reference docs + 1 framework variant |
| mise | 1.1.0 | Skill + 4 reference docs + SessionStart hook |
