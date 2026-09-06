# TDD Verification — BUG-1183 (speckit template ships the Template Version marker)

- **Feature/bug slug**: `1183-speckit-template-version-marker`
- **Branch**: `fix/1183-speckit-template-version-marker`
- **Base**: `master` @ `42840d81`
- **Date**: 2026-09-06
- **Toolchain**: Dart SDK 3.13.3 (stable), linux x64. Flutter absent (example/
  subpackage does not resolve; out of scope for this fix).
- **Engine detection (Step 0 of /speckit.tdd.verify)**: `zfa --version` →
  `zfa v6.1.0`; `.zfa.json` **absent** at repo root → `ZFA_MISSING` →
  **fallback LLM-guided audit per speckit.tdd.verify.md** (same path BUG-1173
  recorded). The deterministic engine was still dispatched for completeness
  (see §1) and its verdict is quoted verbatim.
- **Verdict**: **passed** (for the bug's contract: first plan just works; gate
  unchanged; no regressions). Mutation gate: `not_assessed` — see §1.

## 1. Deterministic engine result (real run, quoted verbatim)

```text
$ dart run bin/zfa.dart tdd verify --feature 1183-speckit-template-version-marker
   receipt preflight: skipped (no receipts shipped — proof-carrying generation not in use)
zfa tdd verify: running mutation audit...
   feature: 1183-speckit-template-version-marker
   feature_dir: /home/z/my-project/zuraffa/specs/1183-speckit-template-version-marker
   gate: not_assessed
   reason: no behavior artifacts registered
   killed: 0
   survived: 0
EXIT: 0
```

`not_assessed` is the correct honest verdict for this bug: the fix surface is
`.specify/templates/spec-template.md` (markdown) plus a regression test file —
there is no lib subject to register in `tdd/artifacts.json` and nothing for
the mutation engine to mutate. No artifacts.json was fabricated to force a
mutation verdict. The scratch `specs/1183-…` dir the engine created was
removed after capturing this output.

## 2. Fix under verification

- `.specify/templates/spec-template.md` (+2 lines): the frontmatter treaty pin
  `**Template Version**: `zuraffa-1.0`` right after the `# Feature
  Specification:` heading — the position green specs author it in and the
  position `SpecMigrator` (#990) inserts at. The #919 gate, the parser, and
  the migrator are UNTOUCHED (reader-side contract of #990 preserved).
- `test/plugins/tdd/bug_1183_speckit_template_version_marker_test.dart` (new):
  T1 non-fenced marker recognized by the REAL gate parser
  (`SpecParser.parseTemplateVersion`, fence stripping included); T2 pinned
  version ∈ `knownTemplateVersions`; T3 marker sits in the frontmatter block;
  T4 verbatim template copy (what `create-new-feature.sh` does) never fails
  the marker gate through the real CLI; T5 a spec authored from the template
  plans green (exit 0, `tdd/test-list.md` written) with no migration step.

## 3. Red evidence (before fix)

CLI through the real pipeline (spec authored by `create-new-feature.sh` from
the unfixed template):

```text
$ dart run bin/zfa.dart tdd plan 1139-repro-1183
zfa tdd plan: contract drift — missing `**Template Version**` marker (spec: /home/z/my-project/zuraffa/specs/1139-repro-1183/spec.md). No test list was written.
  --> fix: run `zfa tdd plan --migrate-spec` to inject the latest template version marker into this spec (issue #990), or author the spec from the zuraffa spec template (zuraffa speckit extension) so it pins a known template version; re-run `zfa tdd plan`.
exit code: 3
```

Test suite pre-fix (new regression file):

```text
00:00 +0 -5: Some tests failed.   # T1, T2, T3, T4, T5
```

T4/T5 failures showed the deterministic exit-3 signature; T4's actual output
contained `missing `**Template Version**` marker` from the real CLI runner.

## 4. Green evidence (after fix)

CLI through the real pipeline (spec authored by `create-new-feature.sh` from
the FIXED template, placeholders filled as the authoring agent does):

```text
$ dart run bin/zfa.dart tdd plan 1140-green-1183
zfa tdd plan: wrote File: '/home/z/my-project/zuraffa/specs/1140-green-1183/tdd/test-list.md' with 1 acceptance + 1 unit behaviors (2 total).
exit code: 0
artifacts on disk: tdd/test-list.md, tdd/traceability.md
```

Test suite post-fix (re-run again after `dart format`, both green):

```text
00:00 +5: All tests passed!   # T1-T5
```

## 5. Full-suite verification (real counts)

Fast suite via the chunked runner's exact semantics
(`dart test <dir> --exclude-tags flutter`, kernel caches cleared between
chunks; interactive timeout forced batching — background processes are reaped
on this agent, so `tools/run_tests_chunked.sh` cannot run to completion in
one shot here):

- Chunks 1–25: 22 ran, 3 SKIP (no fast-tier tests) — **fail=0**
- Chunks 26–50: 24 ran — **fail=0**
- Chunks 51–70: 19 ran, 1 SKIP — **fail=0**
- Chunks 71–90: 19 ran, 1 SKIP — **fail=0**
- 84 chunks ran, 0 chunk failures, 5 by-design skips.

Coverage gap in the repo's chunk walker (pre-existing, NOT introduced here):
`test/plugins/tdd` exceeds the threshold (218 test files), so the walk recurses
into subfolders only and silently skips (a) the 55 loose top-level test files,
(b) `test/plugins/tdd/commands` (42 files, >40, no subdirs → emits nothing).
Those sets were run EXPLICITLY:

- `test/plugins/tdd/commands` → `00:53 +260: All tests passed!`
- `test/plugins/tdd/services` (incl. its registered subdirs) → `01:24 +685: All tests passed!`
- `test/plugins/tdd` loose top-level (55 files, incl. the new bug_1183 suite,
  bug_919, issue_990, spec_template_lanes_1000) → `01:19 +344: All tests passed!`

`dart analyze`: 134 issues (31 error / 103 info) — **all pre-existing**: the
identical 134 was measured on the pristine tree via a `git stash -u` /
`dart analyze` / `git stash pop` round-trip; all 31 errors are
`examples/todo_tdd` uri_does_not_exist (generated fixtures needing the Flutter
SDK). 0 issues reference the changed/new files.

`dart format .`: applied. Final tree idempotence proven: re-running format on
the new test file reports `0 changed`; `git diff --stat` after formatting
contains ONLY the intended fix (+2 template lines) and the new test file.
Note: mid-verify, `dart format` and the test runs transiently touched
`examples/todo_tdd/test/tdd/{a1,u1,u3}_test.dart` — proven to be test-run /
tooling mutation of generated fixtures (HEAD copies are format-stable under
Dart 3.13.3: isolated format of the HEAD blob produces 0 diff), reverted to
HEAD; the PR carries no example/ churn.

## 6. Success criteria — PROVED vs not

- PROVED: spec authored by the speckit pipeline (`create-new-feature.sh`)
  carries the marker (grep: 1 match, line 3).
- PROVED: FIRST `zfa tdd plan` on a template-authored spec exits 0 and writes
  `tdd/test-list.md` + `tdd/traceability.md` (was deterministic exit 3).
- PROVED: the 5-test regression file is red pre-fix (0/5) and green post-fix
  (5/5), asserting the contract through the REAL parser and REAL CLI.
- PROVED: the #919/#990 reader-side gate is unchanged (issue_990 suite green;
  a hand-authored markerless spec still exits 3 in those tests).
- PROVED: fast suite green across all 90 chunks + the walker-skipped tdd sets
  (real pass counts above); `dart analyze` introduces 0 new issues; `dart
  format` leaves 0 formatting diffs in the final tree.
- NOT ASSESSED: the mutation gate (`zfa tdd verify` → `not_assessed`, no
  behavior artifacts registered — the fix ships no lib code to mutate).

## 7. Artifacts

- Fix: `.specify/templates/spec-template.md`
- Tests: `test/plugins/tdd/bug_1183_speckit_template_version_marker_test.dart`
- Records: this file, `cycle-log.md`, `assessment.md`, `issue.md` under
  `.specify/bugs/1183-speckit-template-version-marker/`
