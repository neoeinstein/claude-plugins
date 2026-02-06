# mise Troubleshooting

## When to Use This Reference

- "command not found" errors after mise install
- Tools not using correct version
- Shell activation not working
- Rate limiting errors from GitHub

## Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| Command not found | Run `mise install` then `mise x -- command` |
| Wrong version | Check `mise ls`, run `mise use <tool>@<version>` |
| Activation not working | Check shell rc file, not profile |
| Rate limited | Set `GITHUB_TOKEN` environment variable |

## The Rule

Most mise issues come from one of three sources:
1. Tools not installed (`mise install` not run)
2. Activation not working (wrong shell file)
3. Rate limiting (no GitHub token)

## STOP and Reconsider

**Before removing mise from your CI/CD, STOP.**

| Situation | Why you're wrong | What to do |
|-----------|------------------|------------|
| "CI fails with rate limit, removing mise" | Rate limits are solvable. Removing mise means inconsistent toolchains. | Set `GITHUB_TOKEN`. It takes 2 minutes. |
| "Adding `mise activate` to CI script" | `mise activate` is for interactive shells. CI is not interactive. | Use `mise x -- command` or add shims to PATH. |
| "command not found, mise is broken" | Tools aren't installed automatically. | Run `mise install` first. |
| "Teammate's version differs from mine" | You're not using the lockfile. | Commit `mise.lock`. Run `mise install`. |

## Diagnostic Commands

```bash
# Full system check
mise doctor

# List installed tools
mise ls

# Check which binary is used
which -a node
mise which node

# Verbose output
MISE_DEBUG=1 mise install
```

## Common Issues

### "command not found" After Install

**Cause:** mise not in PATH or not activated.

**Fix 1:** Use `mise x` to run with correct tools:
```bash
mise x -- cargo build
mise x -- npm test
```

**Fix 2:** Ensure activation in correct file:
```bash
# In ~/.bashrc or ~/.zshrc (NOT .bash_profile)
eval "$(mise activate bash)"  # or zsh
```

**Fix 3:** Use shims:
```bash
export PATH="$HOME/.local/share/mise/shims:$PATH"
```

### Rate Limiting

**Symptom:** "API rate limit exceeded" during install.

**Cause:** GitHub API limits unauthenticated requests to ~60/hour.

**Fix:** Create token at https://github.com/settings/tokens (no scopes needed):
```bash
export GITHUB_TOKEN=ghp_your_token_here
# Or
export MISE_GITHUB_TOKEN=ghp_your_token_here
```

Add to shell rc file for persistence.

### Activation Not Working

**Symptom:** Tools not found even after `mise activate`.

**Check:** Is activation in the right file?

| Shell | Correct File | Wrong File |
|-------|--------------|------------|
| bash | `.bashrc` | `.bash_profile` |
| zsh | `.zshrc` | `.zprofile` |

`.bash_profile` and `.zprofile` are for login shells, not interactive shells. `mise activate` only works in interactive shell rc files.

### Wrong Tool Version

**Symptom:** Running old version despite mise.toml.

**Check 1:** Is mise first in PATH?
```bash
which -a node
# mise's node should be first
```

**Check 2:** Is tool installed?
```bash
mise ls node
# Should show installed version
```

**Fix:**
```bash
mise install
mise x -- node --version
```

### Version Not Available

**Symptom:** "No matching version for <tool>@<version>".

**Cause:** Caching or typo.

**Fix:**
```bash
mise cache clear
mise install
```

## Environment Variables for Debugging

| Variable | Purpose |
|----------|---------|
| `MISE_DEBUG=1` | Verbose output |
| `MISE_TRACE=1` | Very verbose output |
| `MISE_LOG_FILE=/path` | Write logs to file |
| `MISE_ACTIVATE_AGGRESSIVE=1` | Force version loading |

## Resources

- [Troubleshooting Guide](https://mise.jdx.dev/troubleshooting.html)
- [FAQ](https://mise.jdx.dev/faq.html)
- [Shims vs Activation](https://mise.jdx.dev/dev-tools/shims.html)
