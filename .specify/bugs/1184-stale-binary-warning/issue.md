# Bug Issue: [CLI] installed zfa binary silently runs stale code after source changes

- **Slug**: 1184-stale-binary-warning
- **Fetched**: 2026-09-06
- **Issue**: 1184
- **State**: open
- **Severity**: medium
- **Author**: arrrrny
- **Labels**: bug, cli

## Body

`~/.local/bin/zfa` is a compiled snapshot. After fixing source in the repo,
every shell `zfa …` invocation kept reproducing the OLD bug — the snapshot
predated the fix. `./scripts/rebuild.sh` exists (its comments reference the
same trap: `.specify/bugs/rebuild-stale-binary`), but nothing tells the
operator the binary is stale.

Observed cost: ~an hour of debugging during the #1159 bug-whole run.

### Telltale available in-process

The snapshot was built from a commit that is NOT `git rev-parse HEAD` of the
repo it is run inside (when run inside a zuraffa checkout).

### Suggestion

- Record the source commit at build time (`scripts/rebuild.sh`) and have the
  CLI print a one-line warning when run inside a zuraffa worktree whose HEAD
  differs:
  `⚠️ installed zfa (<commit>) is older than this checkout (<commit>) — run scripts/rebuild.sh`
- `zfa doctor` could check it too.

### Impact

Any agent or developer testing generator fixes through the shell binary gets
false repros (exactly what the stop-on-roadblock rule punishes).

### Hard constraints

- Add the staleness warning.
- Do not change CLI behavior beyond the warning.
- One PR for the bug.
