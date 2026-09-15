# Verification: 1634-fresh-app-first-build-skip

- **Date**: 2026-09-15
- **Branch**: feat/1634-fresh-app-first-build-skip
- **Base**: origin/master 2ac6b9d7 (Merge PR #1639)
- **Scope audited**: spec.md (SC-1..SC-5), plan.md (D1–D6), tasks.md,
  analysis.md, tdd/test-list.md, tdd/cycle-log.md, changed code, changed
  tests.
- **Provenance**: every number below is from a REAL run in this session
  on the recorded command — nothing copied, stubbed, or back-dated.

## Verdict: VERIFIED for the #1634 fix surface — SC-1..SC-5 all PROVED;
no unrelated pre-existing test failures encountered in the changed-file
neighborhood; the repo-wide suite was deliberately NOT run (cloud-agent
protocol: only test what you changed).

## 1. Red evidence (recorded before implementation)

Source: `tdd/cycle-log.md` T001.

- command: `dart test test/plugins/tdd/services/build_relevance_test.dart`
- result: `00:00 +0 -1: Some tests failed.` — file failed to LOAD with
  exactly 1 analyzer error (`The getter 'staticFirstBuildSkippedNote'
  isn't defined`): the API under test did not exist at HEAD. Corroborated
  with `dart analyze` on the test file: `1 issue found.`
- The old #1624 test asserted the exact fail-open being removed ("a
  missing marker runs the build"); its rewrite into the static matrix IS
  the red phase (S1–S6).

## 2. Green evidence (after implementation)

- change: `lib/src/plugins/tdd/services/build_relevance.dart` ONLY —
  `staticFirstBuildSkippedNote` + private `_staticFirstBuildSkipNote`
  content scan + the `refactorBuildSkipNote` branch (marker AND
  `.dart_tool/build/` both absent → static scan; directory present
  without marker → null; incremental path byte-identical).
- in-cycle catch (T002): the first green run failed S6 — a bare
  `return _staticFirstBuildSkipNote(...)` (no `await`) let the static
  scan's decode error BYPASS the gate's `try/catch`. Fixed with a
  load-bearing `await` + comment; no test edited. S6 now pins the error
  contract it was written for.
- re-ran after `dart format`: `00:05 +39: All tests passed!` (26
  gate + 13 registry), identical counts post-format.

## 3. Test inventory (exact, real counts, final state)

| suite | count | delta vs base |
| ----- | ----- | ------------- |
| test/plugins/tdd/services/build_relevance_test.dart | 26/26 | +6 (S1–S6; the replaced missing-marker test included in the 6) |
| test/plugins/tdd/services/refactor_passes_test.dart | 14/14 | +1 (V1 seam) |
| adjacent: bug_1472_refactor_gate_errors_only + services/subprocess_timeout + scratch_tmpdir | 56/56 | 0 (unchanged, regression watch) |
| combined changed-file suites | 40/40 | +7 |

## 4. Success-criteria audit

| criterion | verdict | evidence |
| --------- | ------- | -------- |
| SC-1 — no-graph + nothing builder-facing → static skip note | **PROVED** | S1 (gate) + S1b/V1 (through the REAL bound gate, registry records `skipped: true`, `exitCode: 0`, `filesChanged: []`, note as output; executor invocations `['format','fix']` — build never spawned) |
| SC-2 — annotated / non-Dart / build.yaml → run | **PROVED** | S2, S3, S4 (each returns null on a no-graph fixture) |
| SC-3 — build-dir-without-marker → run; erroring scan → run | **PROVED** | S5, S6 (S6 via the in-cycle await catch: the decode error fails the decision to null, never throws) |
| SC-4 — #1624 incremental group byte-identical | **PROVED** | the five `writeMarker`-based tests + all #1587 make-gate groups pass with source UNCHANGED from base (extracted section diffs empty against the red-phase commit) |
| SC-5 — analyze + real test runs recorded | **PROVED** | `dart analyze` on all 3 changed files: `No issues found!`; `dart format --set-exit-if-changed` on changed files: clean; repo-wide: `Formatted 2865 files (0 changed)`; counts above |

## 5. Acceptance criteria (issue #1634) mapping

| AC | verdict | mechanism |
| -- | ------- | --------- |
| 1. fresh app's first refactor skips the build when nothing build-relevant exists | **PROVED** | static scan (FR-1..FR-3) → S1/V1 |
| 2. fresh app's first refactor runs the build when build-relevant files ARE present | **PROVED** | S2 (annotations) / S3 (non-Dart) / S4 (build.yaml) |
| 3. one-time AOT compile eliminated or paid outside refactor | **PROVED (eliminated)** for the reported class: the static skip never spawns `zfa build`, so `gen_snapshot` never compiles `build.dart.aot`; when a builder-facing file appears, the next refactor runs the first build (deferred, not fabricated) |
| 4. existing incremental freshness logic unchanged | **PROVED** | SC-4 byte-identity + 56/56 adjacent regression watch |

## 6. Unrelated pre-existing findings (flagged, out of scope)

- Repo-wide `dart analyze` reports 106 infos outside the changed files
  (e.g. `lib/tdd/1334-typed-ui-coverage-ledger/t8_subject.dart`
  `non_constant_identifier_names`) — pre-existing self-hosting-fixture
  style infos in files this branch does not touch.
- `./example` cannot `pub get` in this workspace (needs the Flutter SDK
  for `flutter_test`) — environment limitation, unrelated to the change.
- A transient untracked file (`bug_1588_phase2_refactor_batch...`)
  appeared in `test/plugins/tdd/` during one session run (created and
  cleaned up by some fixture) and is NOT part of the repo (absent from
  HEAD and all history) — noted to prevent confusion; no action.

## 7. Verification protocol hygiene

- Pre-test: `rm -rf .dart_tool/test/` + kernel-cache removal before the
  recorded runs (and between suite groups).
- Post-test: same cleanup; workspace tree clean after commit.
- Post-test cleanup run after the final recorded runs.

## 8. Spec-kit artifacts committed with the code

`spec.md`, `plan.md`, `tasks.md`, `analysis.md`, `tdd/test-list.md`,
`tdd/cycle-log.md`, this file — all under
`.specify/specs/1634-fresh-app-first-build-skip/`, committed on the
feature branch alongside the implementation.
