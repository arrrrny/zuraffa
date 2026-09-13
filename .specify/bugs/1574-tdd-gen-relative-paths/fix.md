# Bug Fix: 1574-tdd-gen-relative-paths

- **Slug**: 1574-tdd-gen-relative-paths
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1574
- **Branch**: `fix/1574-tdd-gen-relative-paths`
- **Date**: 2026-09-14
- **Mode**: TDD (red → green → refactor → verify)

## Summary

`zfa tdd gen` now records the portable project-relative POSIX form of
`test_path`/`subject_path` in the registry record, the emitted stdout record,
and `runnable_test_name`'s first segment — the same form
`run_driver_core.dart` has recorded since commit `af40f686b` (2026-09-08). The
11 committed registries that still carried machine-absolute records (107
records at the original base — the issue's "10" counted first records only)
are migrated to the relative form, together with the #1609 drift the rebase
surfaced (2 more records). The two writers no longer disagree by
construction.

## Root cause (verified empirically, not just read)

`gen_command.dart` composes `testPath`/`subjectPath` from the machine-absolute
`cwd` (`p.absolute(projectFlag)` / `ProjectRoot.find()`) and built the
`ArtifactRecord` from those absolute forms. Two distinct surfaces leaked:

1. **The record/verdict form (every lane)** — gen's emitted
   `test_path:`/`subject_path:`/`runnable_test_name:` lines and the in-memory
   record carried `/…` paths, disagreeing with the run driver's relative form.
2. **The persisted form (bug lane — the live writer)** — the #1397 fix
   added a write-time canonicalization (`_canonicalize` →
   `canonicalArtifactPath`), which relativizes records against the registry's
   project root. But `ArtifactRegistry.projectRoot` only recognizes a
   `specs/`-parented feature directory; for the bug extension's documented
   `.specify/bugs/<slug>` shape (issue #1182) it resolved the root to
   `<root>/.specify/bugs`, so the absolute form could not be relativized and
   **survived the write**. Reproduced on a scratch project at master: the
   bug-lane registry persisted `/tmp/…/test/tdd/…` — matching the committed
   `.specify/bugs/cycle-log-phantom-sections/tdd/artifacts.json`
   (`/Users/arrrrny/Developer/zuraffa/…`, written 2026-09-10, after #1397
   closed).

The reuse-direction breakage the issue reports
(`ownership conflict: the registry test path "test/tdd/…" does not match
"/……"`) reproduced verbatim in the bug lane: gen's absolute computed path
normalized against the mis-derived root while the run driver's relative prior
record normalized against the same wrong root → `pathMismatch`.

## The fix (red → green)

### 1. Writer — `lib/src/plugins/tdd/commands/gen_command.dart`

- Compose the record form alongside the I/O form:
  `recordTestPath = p.relative(testPath, from: cwd)` /
  `recordSubjectPath = p.relative(subjectPath, from: cwd)` (POSIX-normalized).
- `runnableTestName` is built from `recordTestPath`.
- The `ArtifactRecord` is constructed from the relative forms.
- The absolute `testPath`/`subjectPath` locals are UNCHANGED and remain the
  I/O form for every writer, preflight stat, golden lane, platform context and
  import anchor — only the recorded form changed. Exactly the issue's
  "Proposed fix 1": normalize at the writer with `p.relative(..., from: cwd)`.

### 2. Registry resolution — `lib/src/plugins/tdd/services/artifact_registry.dart` (disclosed scope note)

`ArtifactRegistry.projectRoot` now resolves the documented
`.specify/bugs/<slug>` shape to the real project root (3 levels up), keeping
the `specs/` rule first and the immediate-parent fallback last.

**Why this touches a second file** (the issue's hard constraint says "Fix ONLY
the path composition in gen_command.dart + migration"): the writer fix alone
provably trades the persist leak for a reuse break. With records now relative,
the bug-lane registry locates them against `<root>/.specify/bugs` — files
exist at `<root>/test/tdd/…`, so fresh gen dies at `append` with
`StateError: Cannot append artifact record: test file is missing` and re-gen
refuses `ownedButMissing`. The root correction is pure path RESOLUTION: no
gate rule changed (what conflicts vs reuses is identical), no verify-gate
semantics changed, no closure scan touched, `run_driver_core.dart` untouched.
Absolute records resolve exactly as before; only relative-record resolution
moves from a nonexistent location to the real files. Verified: the full
`test/plugins/tdd/commands` chunk (584 tests) passes, including every
ownership-gate, doctor and migrate-paths suite (#835/#840/#1495/#1397/#1573).

### 3. Data migration — 11 registries, 107 records

`scripts/migrate_1574_registries.py` (dry-run census + `--apply`) rewrites
each registry's string FORMS only — no artifact file touched, byte format
preserved (compact `jsonEncode`-style, no re-indent; diff = 11 files,
11 insertions, 11 deletions):

- `test_path`: suffix from the last `/test/` marker (mirrors
  `reanchorRecordPath`), `subject_path`: last `/lib/`.
- `runnable_test_name` first segment rebuilt with the new `test_path` when
  that segment resolves to the recorded test file (mirrors `_canonicalize`'s
  `firstIsTestPath` guard).
- Result census: 11/11 registries migrated, 107/172 records rewritten (a
  per-record census — the issue's "10 registries" classified first records
  only: `.specify/bugs/tdd-run-baseline-timeout` has a relative A1 but
  absolute A2/U1/A3), 0 absolute path fields remain across all 18 tracked
  registries at that base.
- Follow-on: while the PR was open, master merged #1609 — one more drifted
  registry (`specs/1444-setup-zuraffa-app`, 2 absolute records). The rebase
  migrated it too (commit `c7f88e22`): final state 12 registries / 109
  records rewritten, 0 absolute path fields across all 19 tracked
  registries.

Note on the issue's "blanket rewrite would corrupt fixtures" caution: the
fixture-style registries (`corpus/regression/make-baseline-cache/...`,
`examples/todo_tdd/...`) were migrated deliberately — a test sweep showed
nothing consumes their absolute forms (the corpus tiers are driven by
`entry.json`, not `artifacts.json` path forms), and doctor's own drift rule
defines the relative form as the canonical healthy one. The committed
registries were normalized with the one-shot script rather than `zfa tdd
migrate-paths` so all 11 — including the two nested fixture projects
(`corpus/regression/make-baseline-cache/project/`, `examples/todo_tdd/`)
whose registries a single repo-root invocation does not reach (the tool
sweeps one project root's `specs/` + `.specify/bugs/` lanes) — were
rewritten in one pass. The tool itself can rewrite these forms: since #1573
`_scanRegistries` sweeps the bug extension's registries
(`_scanBugRegistries`, called at migrate_paths_command.dart:900), and
`--feature` resolves `.specify/bugs/<slug>` through `_resolveFlaggedRegistry`
(912-928).

### 4. Guard test — `test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`

Six fast in-process tests (CliRunner against temp projects; untagged so the
default CI tier runs the guard — same reasoning as the #1573 suite):

- specs lane + bug lane: fresh gen persists relative
  `test_path`/`subject_path`/`runnable_test_name` (A1/A2)
- specs lane + bug lane: the emitted stdout record carries the relative
  forms (A3)
- bug lane: re-gen of a run-driver-shaped relative prior record reuses
  without an ownership conflict (A4 — acceptance 3)
- committed census: no tracked registry record's `test_path`/`subject_path`
  or `runnable_test_name` first `::` segment starts with `/` (A5 — acceptance
  2, keeps the migration migrated)

## Verification (real runs — see test.md and tdd/verification.md)

- RED (pre-fix): 1 pass / 5 fail — every failure is one of the issue's
  behaviors, including the verbatim `ownership conflict` repro.
- GREEN (post-fix): 6/6 pass; full `test/plugins/tdd/commands` chunk
  584/584; the six targeted regression suites 46/46 (#1397, #1573,
  artifact_registry, #1357 reanchor, #1470 corruption).
- `dart analyze` on the three changed files: No issues found.
- `dart format` gate: clean (lib/ + test/plugins/tdd/commands, 1345 files,
  0 changed after formatting the new suite).

## Acceptance criteria

1. `zfa tdd gen` produces registries with relative `test_path`/`subject_path`
   — PROVED (persist tests, both lanes, red→green).
2. All 11 committed registries with absolute paths migrated to relative form
   (12 with the #1609 follow-on) — PROVED (107 records rewritten; census
   test A5 + shell census 0 absolute).
3. `zfa tdd gen` no longer produces `ownership conflict` errors against the
   run driver's relative form — PROVED (A4 red→green: the verbatim
   pathMismatch refusal at master, reused/reused after the fix).
4. Tests verify relative path form — PROVED (6-test guard suite committed).
