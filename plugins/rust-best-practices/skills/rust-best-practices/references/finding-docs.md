# Finding Documentation

## When to Use This Reference

- Unsure how to use a crate
- Need API documentation for a dependency
- Looking for examples and usage patterns
- Discovering new crates for a task

## Quick Reference

| Need | Tool |
|------|------|
| Crate API docs | docs.rs or `cargo doc` |
| Usage examples | context7 MCP |
| Local project docs | `cargo doc` |
| Crate discovery | crates.io, lib.rs |

## Methods

### context7 MCP (Preferred for Examples)

Use the context7 tools to get up-to-date documentation and code examples:

```
# First, resolve the library ID
mcp__plugin_context7_context7__resolve-library-id
  libraryName: "tokio"
  query: "async runtime spawning tasks"

# Then query the docs
mcp__plugin_context7_context7__query-docs
  libraryId: "/tokio-rs/tokio"
  query: "how to spawn async tasks"
```

Context7 provides code snippets and examples that are more actionable than raw API docs.

### docs.rs (Online API Documentation)

Browse documentation for any published crate at `https://docs.rs/{crate_name}`.

- Direct link: `https://docs.rs/tokio`
- Specific version: `https://docs.rs/tokio/1.35.0`
- Feature flags shown in sidebar
- Source code links included

### cargo doc (Local Documentation)

Generate documentation for your project and dependencies:

```bash
# Build docs for your crate and dependencies
cargo doc

# Include private items
cargo doc --document-private-items

# Only build docs for your crate (faster)
cargo doc --no-deps

# Include optional feature dependencies
cargo doc --features serde
cargo doc --all-features
```

Generated docs are available at `target/doc/{crate_name}/index.html`.

**Note:** If dependencies are behind feature flags (e.g., `serde` as an optional dependency), you may need `--features` or `--all-features` for their docs to be generated.

### crates.io (Crate Discovery)

Search for crates at https://crates.io:
- Sort by downloads, recent updates, or relevance
- Check "Dependents" to see real-world usage
- Review "Dependencies" to understand what you're pulling in

### lib.rs (Curated Discovery)

https://lib.rs provides categorized crate listings:
- Browse by category (async, web, CLI, etc.)
- Quality indicators and comparisons
- Alternative suggestions

## Discovery Workflow

1. **Search context7** first for examples matching your use case
2. **Check docs.rs** for complete API reference
3. **Look at crates.io dependents** to see how popular projects use the crate
4. **Generate local docs** with `cargo doc` for offline access

## Finding Examples

### In Documentation
Most well-documented crates include examples:
- Module-level examples at the top of docs.rs pages
- Function examples in doc comments
- `examples/` directory in the crate repository

### In Tests
Crate test files often show real usage patterns:
```bash
# Clone the crate and look at tests
git clone https://github.com/tokio-rs/tokio
ls tokio/tests/
```

### In Dependents
See how other projects use a crate:
1. Go to crates.io → Dependents tab
2. Pick a well-known project
3. Search their code for imports/usage

## Resources

- docs.rs: https://docs.rs
- crates.io: https://crates.io
- lib.rs: https://lib.rs
- Rustdoc Book: https://doc.rust-lang.org/rustdoc/
