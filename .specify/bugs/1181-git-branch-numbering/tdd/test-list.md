# TDD Test List — 1181-git-branch-numbering (#1181)

Bug: [GIT-EXT] `create-new-feature-branch.sh` derives the branch number from a
counter inflated by GitHub-issue-numbered branches (`fix/1108-…`) instead of
allocating the next sequential spec-tree number. Observed as
`1109-make-engine-preset` where the spec directory resolution allocates
`077-make-engine-preset`.

Target under test: `.specify/extensions/git/scripts/bash/create-new-feature-branch.sh`
(bash, exercised end-to-end through its public CLI in a deterministic sandbox —
the script has no Dart test harness; the repo's bug workflow treats the script
CLI as the behavior surface).

| ID | Behavior | Tier | Kind |
|----|----------|------|------|
| A1 | Sandbox with `specs/076-prior-feature` + branch `fix/1108-some-bugfix` + description mentioning "issue #1109" + `--short-name make-engine-preset` allocates `077-make-engine-preset` (same counter as `create-new-feature.sh`), NOT `1109-make-engine-preset` | red | regression (the bug) |
| A2 | After a real (non-dry-run) allocation, the chosen number is emitted into `.specify/feature.json` as `feature_number` | red | requirement (issue suggestion: emit into feature.json) |
| A3 | Branch name produced by the branch script equals the spec directory name produced by the core `create-new-feature.sh` for the same state (AGENTS.md rule) | red | contract |
| B1 | Branch-only repo (no `specs/`): an exact branch-name collision bumps the allocation (001→002→003) and never proposes an existing name | green-guard | regression guard |
| B2 | Explicit `--number N` still overrides auto-allocation | green-guard | unchanged behavior |
| B3 | `--timestamp` still produces `YYYYMMDD-HHMMSS-<slug>` | green-guard | unchanged behavior |
| B4 | `GIT_BRANCH_NAME` passthrough still uses the exact name and extracts `FEATURE_NUM` | green-guard | escape hatch (documented in README) |
| B5 | `.specify/feature.json` merge preserves pre-existing keys (`feature_directory`) — jq and no-jq paths | green-guard | data safety |
| B6 | `--dry-run` stays side-effect free: no branch, no `feature.json` write | green-guard | contract |
