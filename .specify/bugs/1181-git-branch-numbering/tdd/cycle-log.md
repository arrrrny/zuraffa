# TDD Cycle Log — 1181-git-branch-numbering (#1181)

Deterministic sandbox (built fresh per cycle by
`build_sandbox_1181.sh`, run outside the repo):
git repo on `master` with `specs/076-prior-feature/` (spec tree counter at 076),
a local branch `fix/1108-some-bugfix` modeling the repo's real convention of
naming non-feature branches after GitHub issues, and the invocation from the
bug report: `create-new-feature-branch.sh --json --short-name "make-engine-preset" "Make engine preset (refs issue #1109)"`.

## Cycle 1 — A1/A2/A3 (the bug)

**RED (pre-fix script):**

```
$ .specify/extensions/git/scripts/bash/create-new-feature-branch.sh --json \
    --short-name "make-engine-preset" "Make engine preset (refs issue #1109)"
{"BRANCH_NAME":"1109-make-engine-preset","FEATURE_NUM":"1109"}
```

Control — the counter the branch must agree with (core spec-directory
resolution, same sandbox):

```
$ .specify/scripts/bash/create-new-feature.sh --json --dry-run \
    --short-name "make-engine-preset" "Make engine preset (refs issue #1109)"
{"BRANCH_NAME":"077-make-engine-preset","SPEC_FILE":".../specs/077-make-engine-preset/spec.md","FEATURE_NUM":"077","DRY_RUN":true}
```

Branch `1109` vs spec dir `077` — bug reproduced exactly as reported. A1 FAIL,
A2 FAIL (no feature.json emitted at all), A3 FAIL.

Root cause (from the RED trace, not assumption): auto-allocation called
`check_existing_branches()` = `1 + max(highest spec dir, highest number
harvested from ALL local+remote branch final segments matching ^[0-9]{3,}-)`.
The repo's issue-numbered bugfix branches (`fix/1108-…`, `spec/1106-…`) pass
that filter, so the "sequential feature counter" ingested the GitHub-issue
stream: max issue branch 1108 + 1 = 1109 — structurally equal to the next
issue number the description references (`#1109`). The description text was
never literally parsed; the branch scan imported issue numbering, which is
what the issue title observes.

**GREEN (fix):** allocation now uses the spec-tree counter only
(`1 + max(specs/NNN-*)` — the same counter `create-new-feature.sh` uses) and
never parses numbers out of branch/ref names; only an exact branch-name
collision bumps the number. After creating the branch, the chosen number is
emitted into `.specify/feature.json` (`feature_number`).

```
$ .specify/extensions/git/scripts/bash/create-new-feature-branch.sh --json \
    --short-name "make-engine-preset" "Make engine preset (refs issue #1109)"
{"BRANCH_NAME":"077-make-engine-preset","FEATURE_NUM":"077"}
$ cat .specify/feature.json
{"feature_number":"077"}
```

Agreement check (fresh sandbox, same state):

```
branch script  -> BRANCH_NAME=077-make-engine-preset
core script    -> specs/077-make-engine-preset
AGREE: branch '077-make-engine-preset' == spec dir '077-make-engine-preset'
```

A1 PASS, A2 PASS, A3 PASS.

## Cycle 2 — guards (no regressions)

| Test | Command shape | Result |
|------|---------------|--------|
| B1 | branch-only repo (specs removed), branches `001-next-thing`, `002-next-thing` exist | `{"BRANCH_NAME":"003-next-thing",…}` — exact collisions walked past, no foreign numbers ingested. PASS |
| B2 | `--number 42` | `{"BRANCH_NAME":"042-answer",…}`. PASS |
| B3 | `--timestamp --short-name ts-test` | `20260906-102633-ts-test` (matches `^[0-9]{8}-[0-9]{6}-…`). PASS |
| B4 | `GIT_BRANCH_NAME=999-custom-name` | `{"BRANCH_NAME":"999-custom-name","FEATURE_NUM":"999"}`. PASS |
| B5 | pre-existing `{"feature_directory":"specs/050-old"}` then run | jq path: `{"feature_directory":"specs/050-old","feature_number":"077"}`; no-jq path (jq hidden from PATH, synthetic coreutils-only env): same merge, valid JSON; repeat run updates the value in place. PASS |
| B6 | `--dry-run` | computes `077-dry`, creates no branch, writes no `feature.json`. PASS |

## Refactor

Not required — the fix also deleted the now-dead number-harvesting helpers
(`get_highest_from_branches`, `_extract_highest_number`,
`get_highest_from_remote_refs`, `check_existing_branches`) so the "never parse
numbers out of ref names" rule is structural, not conventional. No external
callers (grep-verified repo-wide; the python/powershell twins carry their own
independent copies).
