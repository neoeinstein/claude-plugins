# mise in CI/CD

## When to Use This Reference

- Setting up mise in GitHub Actions
- Using mise.lock for reproducible builds
- Caching mise tools in CI
- Running tools in non-interactive environments

## Quick Reference

| Pattern | When to Use |
|---------|-------------|
| `mise-action` | GitHub Actions with caching |
| `mise x -- cmd` | Run tool with correct version |
| `mise.lock` | Reproducible builds |
| Shims in PATH | IDE/editor integration |

## The Rule

CI environments are non-interactive. Don't use `mise activate` — it's for interactive shells. Use `mise x -- command` or add shims to PATH.

**Always set `GITHUB_TOKEN`** to avoid rate limiting.

## Patterns

### GitHub Actions with mise-action

```yaml
name: CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: jdx/mise-action@v2
        with:
          install: true
          cache: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - run: cargo test
      - run: cargo build --release
```

The action:
- Installs mise
- Runs `mise install`
- Caches tools based on mise.toml
- Adds shims to PATH

### Manual Setup (Any CI)

```yaml
- name: Install mise
  run: |
    curl https://mise.run | sh
    echo "$HOME/.local/share/mise/shims" >> $GITHUB_PATH
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: Install tools
  run: mise install

- name: Build
  run: cargo build
```

### Using mise x Explicitly

When shims aren't in PATH:

```yaml
- run: mise x -- cargo test
- run: mise x -- npm run build
```

### Reproducible Builds with mise.lock

Generate lockfile:
```bash
mise install
# mise.lock is created/updated
git add mise.lock
git commit -m "chore: update mise.lock"
```

The lockfile contains:
- Exact download URLs
- SHA256 checksums
- Version metadata

**Always commit mise.lock** for reproducible builds.

### Caching Strategy

With mise-action, caching is automatic. Manual setup:

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.local/share/mise
      ~/.cache/mise
    key: mise-${{ hashFiles('mise.toml', 'mise.lock') }}
```

### GitLab CI

```yaml
.mise:
  before_script:
    - curl https://mise.run | sh
    - eval "$(~/.local/bin/mise activate bash)"
    - mise install
  cache:
    key: mise-$CI_COMMIT_REF_SLUG
    paths:
      - ~/.local/share/mise
      - ~/.cache/mise

build:
  extends: .mise
  script:
    - cargo build --release
```

### Rate Limiting Prevention

Always set GitHub token:

```yaml
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  # Or mise-specific:
  MISE_GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Without token: ~60 requests/hour (often exceeded)
With token: ~5000 requests/hour

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Using `mise activate` in CI | Tools not found | Use shims or `mise x` |
| Missing `GITHUB_TOKEN` | Rate limit errors | Set token in env |
| Not caching mise | Slow builds | Enable caching |
| Not committing `mise.lock` | Version drift | Commit lockfile |

## Resources

- [CI/CD Guide](https://mise.jdx.dev/continuous-integration.html)
- [mise-action](https://github.com/jdx/mise-action)
- [Lockfile](https://mise.jdx.dev/dev-tools/mise-lock.html)
