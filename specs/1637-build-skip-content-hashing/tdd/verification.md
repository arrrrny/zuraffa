# Verification: 1637-build-skip-content-hashing

Date: 2026-09-15 · Branch: `feat/1637-build-skip-content-hashing`

## Method

Every claim on this page comes from commands executed in THIS checkout
against the real service layer (`lib/src/plugins/tdd/services/
build_relevance.dart`) — nothing is asserted from reading code alone.
The red→green discipline: the 12 new tests were written first, run on
the pre-fix tree, and observed FAILING (9 behavioral reds + 3
fail-safe guards that are green by construction — a pre-fix gate that
runs on ANY newer config cannot be made to fabricate a skip); then
T101 landed and every suite below was re-run and observed passing.
Mutation evidence is deliberate-mutant sampling (no mutation tool is
wired in this repo per `.specify/memory/tdd-profile.md`), each mutant
patched onto the real source, run, and restored.

## Red evidence (pre-fix tree, commit `c760fa63` + tests, before T101)

`dart test test/plugins/tdd/services/build_relevance_test.dart
test/plugins/tdd/services/refactor_passes_test.dart` → **9 failed, 37
passed**. The reds (all for the right reason — the gate had no
baseline mechanism and forced RUN on any newer config file):

| behavior | observed failure |
| --- | --- |
| A1 byte-identical refresh skips | `Expected: true / Actual: <false>` on `the run decision records the config baseline` — the gate never records; the skip assertion is unreachable |
| A2 real change re-records | read of the nonexistent baseline file throws |
| A3 missing/corrupt/wrong-version records | `existsSync` false (no recording) |
| A5 dart_test.yaml identical refresh skips | expected the skip note, got null |
| U1 fingerprint digests trusted | expected the skip note, got null |
| U2 mixed-tree skip | expected the skip note, got null |
| U4 baseline is version-1 JSON | file absent |
| U5 skip path never rewrites | expected the skip note, got null |
| A6/T006 registry-bound gate skips | expected the skip note, got null |

Green by construction (fail-safe guards, cannot be red pre-fix): A4
(untrusted-baseline validity), U3 (one-wrong-digest runs), A5b (real
analysis_options change runs).

## Green evidence (post-fix)

### Suites

| suite | result |
| --- | --- |
| `test/plugins/tdd/services/build_relevance_test.dart` + `refactor_passes_test.dart` | **46 passed, 0 failed** (34 baseline + 12 new) |
| `test/plugins/tdd/services/` (full sweep) | **1111 passed, 0 failed** |
| `test/plugins/tdd/make_command_1587_build_skip_test.dart` + `make_command_1587_dedup_test.dart` (shared BuildRelevance surface, untouched #1587 contracts) | **8 passed, 0 failed** |
| `dart analyze lib/src/plugins/tdd/services/build_relevance.dart test/plugins/tdd/services/build_relevance_test.dart test/plugins/tdd/services/refactor_passes_test.dart` | No issues found |
| `dart format` on the three changed files | clean; `git diff` shows zero remaining formatting diffs |

### Behavior-by-behavior verdicts (test-list)

- **A1 (AC-1, SC-001 — the reported regression)** — PASS. First gate
  call on a newer config with no baseline → null + baseline recorded;
  marker moved (completed build); byte-identical refresh → the skip
  note. The mtime-only gate returned RUN here.
- **A2 (AC-2, SC-002)** — PASS. Trusted baseline, real content change →
  null, and the re-recorded baseline carries the new digest, equal to
  `fingerprint`'s digest of the same bytes.
- **A3 (AC-3, SC-003)** — PASS. Missing / corrupt (`\u0000…` garbage) /
  wrong-version (999, with matching digests and a strictly-older
  marker) → null every time, and each decision re-records a version-1
  baseline.
- **A4 (AC-4, SC-004)** — PASS. Baseline whose recorded marker mtime
  EQUALS the current marker's → null (run) even with fully matching
  digests — validity needs a completed build.
- **A5 (AC-5, SC-005)** — PASS. `dart_test.yaml` byte-identical refresh
  → skip note; real `analysis_options.yaml` change → null.
- **A6 (AC-6, SC-006)** — PASS. The #1624 group (6 tests) unchanged and
  green: missing marker → run; no newer file → skip; annotated .dart →
  run; non-Dart → run; plain .dart → skip; tree-unchanged → skip. The
  registry binding test (`refactor_passes_test.dart`) proves the bound
  gate (not a stub) produces the verdicts, plus the new #1637 binding
  test proves the pass is not spawned on a cleared tree (SC-007).
- **U1 (FR-003)** — PASS. A baseline seeded from
  `BuildRelevance.fingerprint`'s config digests is trusted → skip:
  fingerprint-derived and baseline digests are one currency.
- **U2 (FR-001/FR-002)** — PASS. Cleared config tier + newer plain
  .dart → skip (mixed tree).
- **U3 (FR-001/FR-005)** — PASS. One wrong digest in an otherwise
  trusted baseline → null (per-file comparison, never wholesale).
- **U4 (FR-004/FR-006)** — PASS. Recorded baseline is version-1 JSON at
  `.dart_tool/zfa/build_config_baseline.json` with `markerMtimeMillis`
  equal to the PRE-build marker and digests covering every existing
  config file, each equal to `fingerprint`'s.
- **U5 (FR-006)** — PASS. After a skip decision the baseline bytes are
  unchanged and a follow-up call still skips (no self-invalidation).
- **U6 (FR-005)** — PASS. The `refactorBuildSkipNote (issue #1624)`
  group passes byte-identical to pre-fix.

## Mutation evidence (deliberate mutants, all killed)

Each mutant patched onto the real source, then
`dart test test/plugins/tdd/services/build_relevance_test.dart`, then
`git checkout` restore. Post-run integrity: source restored (clean
`git status`), suite back to 32 passed.

| mutant | change | verdict | killed by |
| --- | --- | --- | --- |
| M1 | validity relaxed: `<` → `<=` (a record whose marker equals the current marker becomes trusted) | KILLED (+31 −1) | A4 — untrusted-baseline validity |
| M2 | digest comparison inverted (mismatch clears, match runs) | KILLED (+25 −7) | A1, A2, and 5 more |
| M3 | digest snapshot returns an empty map (per-file comparison degenerates) | KILLED (+27 −5) | A1 + 4 more |
| M4 | the skip path rewrites the baseline (self-invalidation) | KILLED (+31 −1) | U5 |
| M5 | baseline version check removed | KILLED (+31 −1) | A3 (strengthened during this verify: the wrong-version record now carries MATCHING digests and a strictly-older marker, so the version gate is the only barrier — the original wording was survivable, found and fixed by this mutation round) |

## Acceptance-criteria coverage

AC-1 → A1 · AC-2 → A2 · AC-3 → A3 · AC-4 → A4 · AC-5 → A5 ·
AC-6 → A6 (+ the unchanged #1624 group). FR-001..FR-007 map to U1–U6
as traced in `tdd/test-list.md`; FR-008 is asserted by the unchanged
#1624 group, the unchanged #1587 make suites (8 passed), and the
absence of any registry/build-command/asset-graph change in the diff
(only `build_relevance.dart` + its two test files carry Dart changes).

## Verdict

**GATE PASSED.** Test-first discipline proven (real reds, recorded in
`cycle-log.md`), 46/46 targeted and 1111/1111 services-sweep tests
green, 1587 make-gate suites unchanged green, format and analyze
clean, 5/5 sampled mutants killed with the surviving-mutant finding
(A3's strength) remediated inside this verify pass. No remediation
tasks open.
