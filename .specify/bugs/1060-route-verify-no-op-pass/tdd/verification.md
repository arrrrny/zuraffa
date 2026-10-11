# TDD Verification — 1060-route-verify-no-op-pass

- **Date**: 2026-09-05
- **Engine**: LLM-guided fallback (bug dir not under `specs/`; the
  `zfa tdd verify --feature` artifacts.json flow requires `specs/<feature>/`,
  which does not exist for `.specify/bugs/1060-route-verify-no-op-pass/`)
- **Scope**: `lib/src/commands/route_verify_command.dart`,
  `test/plugins/route/route_verify_verdict_test.dart` (new),
  `test/plugins/route/scenarios/sc_001_route_verify_test.dart` (updated),
  `.specify/bugs/1060-route-verify-no-op-pass/*` (records)
- **Gate verdict**: **PASSED** (with disclosed deviations, below)

## 1. Test-first evidence

- Baseline RED (the bug itself) reproduced against base 77e69f24 before any
  implementation change: CASE A/B/C/D all dishonest (see cycle-log.md).
- Contract-first RED: `route_verify_verdict_test.dart` written and run
  BEFORE the verdict layer existed → 10/10 failed
  (missing `verdict`, exit codes, `oneSided`, `missingInput`, strict
  escalation, help contract).
- Implementation landed after the failing tests existed. Timestamps and
  commands in `cycle-log.md`.

## 2. Suite status (scoped, per the bug's hard constraint)

`dart test test/plugins/route/ test/cli/route_command_test.dart`
→ **69/69 pass** (0 failures, 0 skipped in scope).

Includes: new verdict tests V1–V7 (10), updated sc_001, existing sc_002,
U2 detector contract, U1 route table, bug_912 regression guard,
U4 CLI surface.

Full suite NOT run — the bug orders say "Run ONLY route plugin scoped suite
plus new tests … Do NOT run full suite." `tools/run_tests_chunked.sh` (the
standing full-fast-suite runner) was therefore intentionally not executed.

## 3. Analyzer

- `dart analyze` on all three changed Dart files → **No issues found!**
- Repository-wide `dart analyze` reports 345 pre-existing issues confined to
  `examples/` (Flutter-SDK-dependent), `lib/tdd/` fixtures and
  `test/tdd/`/`test/plugins/tdd` helpers. None intersect the changed files;
  none were introduced by this branch (verified by scoping the analyzer to
  the changed files).

## 4. Formatting

`dart format .` → 1979 files formatted, 0 changed beyond the branch's own
edits; `git diff --stat` after format shows only the branch's two modified
files. Zero remaining formatting diffs.

## 5. Mutation spot-checks (test strength)

Fallback mutation audit — three hand-applied mutants on the verdict layer,
each reverted after the run:

| Mutant | Change | Result |
|--------|--------|--------|
| M1 | `insufficientInput exitCode: strict ? 1 : 2` → `2` (kill `--strict` escalation) | **Killed** — V4 red |
| M2 | remove the path-set agreement branch (match unreachable → always drift) | **Killed** — V1 red |
| M3 | `_oneSidedFindings` → `const []` (hide one-sided drift) | **Killed** — V2, V2b, V6 red |

Post-restore confirmation: verdict suite 10/10 green. No surviving mutants
in scope. (Mutation scope is the verdict layer only; the untouched
`RouteDriftDetector` retains its existing U2 contract.)

## 6. Acceptance criteria coverage

| AC (issue #1060) | Evidence | Status |
|------------------|----------|--------|
| verify detects real drift on fixture with mismatched route tables | V2/V2b (one-sided paths named), sc_002 (overlap drift, exit 1 with `--strict`) | PROVED |
| verify emits insufficient-input (not PASS) when inputs missing, with distinct exit code | V3/V3b/V3c (exit 2, `missingInput` names the missing system), V6 (text distinguishable from match) | PROVED |
| All three verdict classes covered by tests, exit codes pinned | V1 (match→0), V2/V2b (drift→1), V3* (insufficient-input→2), V4 (strict→1), V5 (help documents 0/1/2) | PROVED |
| Scoped route suite green | 69/69 pass (section 2) | PROVED |

Hard constraints honored:

- No new dependencies (`pubspec.yaml` untouched).
- `RouteDriftDetector` untouched — `git diff` shows zero changes to
  `route_drift_detector.dart`; walkers feed it via the existing
  `detect(RouteTable)` API.
- Hand-rolled parsing consistent with the existing route plugin code
  (same `_parseRoutes` machinery, extended to `*_shell.dart`).

## 7. Disclosed deviations

1. `sc_001_route_verify_test.dart` expectation updated from "exits 0 with
   no drift" to "insufficient-input (exit 2)" on an empty project. The old
   expectation was itself the lie-certifying PASS this bug removes; the
   scenario's core intent (end-to-end runnable) is preserved.
2. `tools/run_tests_chunked.sh` not executed (full-suite prohibition in the
   bug's hard constraints; see section 2).
3. Verdict semantics for full path-set agreement: overlap findings from the
   detector are treated as reconciled agreements when the two systems'
   path sets are identical (verdict `match`), and as conflicts otherwise
   (verdict `drift`). This is the only non-degenerate reading of order 4(a)
   ("matching systems → match") that keeps the detector's pure API and its
   U2 contract intact. The overlap entries remain fully visible in the
   `routes` array of the JSON artifact.
4. The issue's "walkers never landed" root cause is partially stale on this
   base: file discovery landed with spec 0971 (31e7b012). The honest
   verdict layer — the actual subject of the bug — had not landed; that is
   what this branch delivers, and the baseline RED evidence documents the
   no-op PASS behavior as filed.
