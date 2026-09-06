# TDD Verification — BUG-1188 (stop-on-roadblock PROGRESS.md path gitignored)

- **Feature/bug slug**: `1188-gitignore-progress-md`
- **Branch**: `fix/1188-gitignore-progress-md`
- **Base**: `master` @ `42840d81`
- **Date**: 2026-09-06
- **Toolchain**: Dart SDK 3.13.3 (stable), linux_x64; no Flutter SDK (pure-Dart
  package; flutter-tagged tests excluded by the suite contract).
- **Engine detection (Step 0 of /speckit.tdd.verify)**: `zfa --version` absent
  from PATH, `.zfa.json` absent → `ZFA_MISSING` → **fallback LLM-guided audit
  per speckit.tdd.verify.md** (deterministic `zfa tdd verify` engine not wired
  at repo root).
- **Verdict**: **passed**

## 1. Fix under verification (ownership decision: un-ignore, the bug's option 1)

AGENTS.md mandates the stop-on-roadblock record at
`apps/zikzak_demo/PROGRESS.md`, but `git add` refused it. Root cause: the root
`.gitignore` carried BOTH an early bare `apps/` rule (line 12) AND the later
intentional narrowing block:

```gitignore
/apps/*            # scratch apps stay ignored
!apps/zikzak_demo/ # bug 501's mock ZikZak app is a committed deliverable
```

Git cannot re-include a path whose parent directory is excluded, so the bare
`apps/` rule silently defeated the `!apps/zikzak_demo/` negation —
`git check-ignore -v` attributed the refusal to `.gitignore:12:apps/`, not to
`/apps/*`. The 15 already-tracked files under `apps/zikzak_demo/` kept working
(tracked files bypass ignore rules), which masked the defect until a NEW file
— exactly what a stop record is — could not be added.

Fix (minimal, `.gitignore`-only):

- Removed the bare `apps/` rule from root `.gitignore`. The later
  `/apps/*` + `!apps/zikzak_demo/` block already expresses the narrowed intent
  and becomes fully effective once no rule excludes the `apps` parent.
- Replaced the removed line with a BUG-1188 comment forbidding re-introduction
  of a bare `apps/` rule (the exact regression vector this PR guards).
- AGENTS.md is UNCHANGED: the mandated path `apps/zikzak_demo/PROGRESS.md`
  becomes committable, which is the bug's preferred resolution (option 1);
  the #1177 workaround (`specs/<feature>/PROGRESS.md`) stays valid but no
  longer needs to be the convention.
- Added `test/regression/issue_1188_gitignore_progress_md_test.dart` —
  fast-tier regression guard (behavioral `git check-ignore` contract +
  syntactic defense in depth; runs in the default `dart test` tier).

## 2. Red evidence (before fix)

### 2.1 The bug's exact reproduction — `git add` refusal

```text
$ printf '# PROGRESS — zikzak sandbox bring-up (stop-on-roadblock record)\n\n## Resume marker\n\n- **Stopped at**: repro of bug 1188 — this file must be committable per AGENTS.md mandate.\n' > apps/zikzak_demo/PROGRESS.md
$ git add apps/zikzak_demo/PROGRESS.md
EXIT_CODE=1
stderr:
The following paths are ignored by one of your .gitignore files:
apps
hint: Use -f if you really want to add them.
```

Diagnosis before fix:

```text
$ git check-ignore -v apps/zikzak_demo/PROGRESS.md
.gitignore:12:apps/	apps/zikzak_demo/PROGRESS.md
exit=0
```

### 2.2 New regression guard (RED)

```text
$ dart test test/regression/issue_1188_gitignore_progress_md_test.dart   # pre-fix
00:00 +0 -1: BUG-1188: AGENTS.md-mandated apps/zikzak_demo/PROGRESS.md is not gitignored [E]
  Expected: <1>
    Actual: <0>
  apps/zikzak_demo/PROGRESS.md (the AGENTS.md stop-on-roadblock record) must be
  committable, but git check-ignore reports it ignored:
  .gitignore:12:apps/	apps/zikzak_demo/PROGRESS.md
00:00 +0 -1: Some tests failed.
```

## 3. Green evidence (after fix)

### 3.1 Guard test green

```text
$ dart test test/regression/issue_1188_gitignore_progress_md_test.dart
00:00 +1: All tests passed!
```

### 3.2 The bug's repro now passes end-to-end

```text
$ git check-ignore -v -- apps/zikzak_demo/PROGRESS.md; echo "exit=$?"
exit=1                                    # not ignored
$ git add apps/zikzak_demo/PROGRESS.md; echo "exit=$?"
exit=0                                    # staged successfully (git status: A)
# stub then unstaged + deleted: a synthetic stop record must not pollute the
# tree; the durable regression guard is the test, not a fabricated PROGRESS.md
```

### 3.3 The narrowing intent survives (no regression in the other direction)

```text
$ git check-ignore -v -- apps/some_scratch_app/x.txt
.gitignore:51:/apps/*	apps/some_scratch_app/x.txt
exit=0                                    # scratch apps STILL ignored
```

### 3.4 Fast-suite + analyzer delta vs master baseline

```text
                       errors  warnings  infos
master (git stash -u)      31         0    103
this branch                31         0    103
delta                       0         0      0
```

All 31 master errors are pre-existing `examples/` nested-package noise
(`uri_does_not_exist` in the unresolved `examples/todo_tdd` Flutter app — the
repo's documented `--no-example` convention). Zero analyzer issues touch the
changed files.

Fast suite (chunked runner semantics, Dart 3.13.3):
**3490 tests passed, 0 failed**, 84/90 chunks ran green and 6 chunks reported
"no fast-tier tests" (by-design skips per `tools/run_tests_chunked.sh`:
`test/benchmark`, `test/core/dependencies`, `test/core/proof`,
`test/integration`, `test/plugins/tdd/scenarios`,
`test/tdd/077-make-engine-preset`). 90/90 chunks accounted for.

## 4. Mutation testing on the changed guard (fallback audit requirement)

Each mutant applied to the fixed tree, guard re-run, then reverted:

| Mutant | Change | Guard result |
|---|---|---|
| M1 | Re-add bare `apps/` rule to root `.gitignore` | **killed** (exit 1; behavioral clause fired: `check-ignore` reported the path ignored again) |
| M2 | Comment out `!apps/zikzak_demo/` negation | **killed** (exit 1; behavioral clause fired: `/apps/*` then matches the subtree with no negation) |
| control | no mutation | passed (exit 0) |

2/2 mutants killed — the guard is not a tautology: it detects both halves of
the regression space (parent rule re-introduced AND narrowing negation
removed).

## 5. Test-smell rubric (guard test)

- Deterministic: one `git check-ignore` process spawn + a line-based scan of
  root `.gitignore`; no network, no time, no RNG.
- Fast: sub-second, default fast tier (no `slow` tag) — runs on every CI job.
- No assertion roulette: each clause carries a `reason` naming BUG-1188 and
  the exact ignore-mechanics rule it enforces (parent-exclusion defeats
  negation).
- Behavior-centric: clause 1 asserts the observable contract (the
  AGENTS.md-mandated path is committable), clauses 2–3 pin the mechanism so
  mutants cannot pass by coincidence.
- Environment guard: `git check-ignore` exit 128 (not a git work tree) is a
  `markTestSkipped`, so a non-checkout context cannot fake a red suite.

## 6. Acceptance criteria → status

| Criterion (from bug record) | Status |
|---|---|
| RED: `git add apps/zikzak_demo/PROGRESS.md` refused pre-fix | **PROVED** (§2.1, §2.2) |
| GREEN: mandated path committable post-fix (check-ignore exit 1, git add exit 0) | **PROVED** (§3.1, §3.2) |
| `apps/` scratch-ignore intent preserved (option 1 "narrow the ignore", not a blanket un-ignore) | **PROVED** (§3.3) |
| AGENTS.md and .gitignore agree | **PROVED** — AGENTS.md mandates `apps/zikzak_demo/PROGRESS.md`; `.gitignore` no longer blocks it (AGENTS.md untouched) |
| Regression guard in default CI tier, mutation-verified | **PROVED** (§4, §5) |
| Fast suite green on this branch | **PROVED** (§3.4: 3490 passed / 0 failed) |
| One PR, `Closes #1188` | **PROVED** — single PR from `fix/1188-gitignore-progress-md` |

## 7. Deviations / notes

- `specify init` was not re-run against the existing `.specify/` tree: the
  repo is already initialized at the same speckit version (`1.0.5.dev0`, zed
  integration; `specify extension list` → `✓ TDD Extension (v1.1.2)`), and a
  force-merge would re-scaffold stock templates over the committed, customized
  `.specify/` (the standing warning forbids clobbering
  `.specify/templates|scripts`). The end state `init` would produce is already
  present; verified instead of re-created.
- `.specify/bugs/1188-*/issue.md` / `assessment.md` were not present in the
  repo (task anticipated "if exists"); the bug record shipped with the task
  brief was used as sole triage input (same handling as BUG-1173).
- Root `dart pub get` requires `--no-example` on this toolchain (pub 3.13
  recurses into the unresolved nested `examples/` Flutter app; the repo's own
  conventions document the same).
- `tools/run_tests_chunked.sh` semantics were executed chunk-by-chunk with
  byte-identical per-chunk commands (`dart test "$d" --exclude-tags flutter`,
  kernel-cache cleanup between chunks, same emit_chunks list — 90 chunks) via
  a resume-capable driver, because this sandbox reaps any process that
  outlives a single tool call (~10 min) and a monolithic run cannot survive
  it. Results in §3.4 are from that faithful execution; 6 of 90 chunks were
  "no fast-tier tests" skips by the script's own design, not failures.
- `dart format .` (dart_style shipped with Dart 3.13.3) flags 3 pre-existing
  files under `examples/todo_tdd/` — formatter-version drift already present
  on `master`, outside this bug's scope; those hunks were reverted to keep the
  PR minimal. `git diff --stat` after `dart format .` shows zero remaining
  formatting diffs for this PR's files (the new guard is format-clean:
  `Formatted 1 file (0 changed)`).
- Disk housekeeping: downloaded SDK archives, kernel caches, and per-run logs
  were deleted after each phase; nothing outside the working clone was
  touched, and no source or committed bug record was deleted.
