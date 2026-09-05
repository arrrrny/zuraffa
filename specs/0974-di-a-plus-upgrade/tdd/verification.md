feature: 0974-di-a-plus-upgrade (issue #974, branch spec/0974-di-a-plus-upgrade)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree at spec/0974-di-a-plus-upgrade (base 77e69f24) + this session's real runs
behaviors: 11
proven: 11
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 3/3 # deliberate mutants, no mutation tool in profile (.specify/memory/tdd-profile.md); all caught, restoration verified byte-exact (git checkout HEAD; per-file suites re-green after each restore)
mutants_survived: 0
suite: fast tier chunked 74/74 chunks OK (60 in run 1, range 61-74 in run 2), 2918 passed / 0 failed — includes the new test/plugins/di chunk additions (29 tests in folder, 29/29 green); targeted: dead_command_gone 3/3, di_verify 5/5, di_receipts 4/4, di_verdicts 4/4; dart analyze 345 issues = pre-feature baseline 345 (zero new); dart format (Dart 3.13.3) --set-exit-if-changed lib test exit 0
method: /speckit.tdd.verify fallback (engine detection ZFA_MISSING — .zfa.json absent in this repo) — LLM-guided audit per the command file: cycle-log red evidence appended through the real hash-chained CycleLog writer, git-history ordering, rubric, deliberate-mutant sampling, acceptance-criteria coverage, real CLI smoke; every number above is from a real run in this session

# TDD Verification: di A+ upgrade (spec 0974, issue #974)

**Verdict: PASS.** All 11 behaviors (4 acceptance + 7 unit) have recorded
red evidence appended through the real `CycleLog.append` writer (schema-1
hash chain, 8 entries), the red state of every acceptance behavior was
re-derived FRESH in this session by checking the tree out at each task's
pre-implementation commit and re-running the failing test (captured in
`tdd/cycle-log.md`), the full fast tier is green with the new
`test/plugins/di` files included (2918 passed / 0 failed across 74
chunks), analysis is count-identical to the pre-feature baseline (345
issues, zero new), the CI formatter gate passes, and all three
deliberate mutants were caught — including the exact bug the issue
exists to kill (a generation failure dressed up as `success: true`),
which ONLY the new A4 test catches.

## Engine detection (the command file's Step 0)

```text
zfa --version   -> zfa v6.1.0     (OK)
test -f .zfa.json -> ZFA_MISSING
```

Per `.specify/extensions/tdd/commands/speckit.tdd.verify.md`, `ZFA_MISSING`
takes the documented **fallback path** (LLM-guided audit), matching the
repo's precedent (specs 066, 071, bug tdd-133/939 records were produced on
the same path; the profile notes no mutation tool is wired in CI).

## Test-first evidence (red)

Each task followed red → green inside the session, and the branch commits
one commit per task (test + implementation together — commit granularity
is combined, stated openly here). Because combined commits weaken the
git-ordering signal, the red phase was re-proven deterministically at
verification time: for each acceptance behavior the tree was restored to
the pre-implementation state via `git show <task-commit>^ / git checkout
<task-commit>^ -- <files>`, the new test file was executed against it, and
the failing output + exit code + UTC timestamp were captured and appended
through the real `CycleLog` writer (schema 1, per-behavior hash chain —
tamper-evident, fsynced). The tree was restored byte-exact afterwards
(`git checkout HEAD`, verified clean).

| behavior | pre-impl state | red classification | red exit |
|---|---|---|---|
| A1 | `di_command.dart` resurrected from `40dbf88f^` | assertionFailure (`expect(...existsSync(), isFalse)` at line 31) | 1 |
| A2 | `DiVerifyCapability` absent (`69766971^`) | compileError (`Method not found: 'DiVerifyCapability'`) | 1 |
| A3 | `DiReceiptWriter` absent (`edf3984e^`) | compileError (`No named parameter 'projectRoot'`) | 1 |
| A4 | verdict fields absent (`c3dda65d^`) | compileError (`No named parameter 'warnings'`) | 1 |

All four tests pass at HEAD (green entries recorded in the same chain,
exit 0). The inner-loop U-rows ride the same files and the same red runs
(each file failed as a unit before its implementation existed).

## Mutation testing (deliberate-mutant sampling, rubric Q3)

| mutant | mutation | caught by | run |
|---|---|---|---|
| M1 | verify gate's failure verdict neutered (`success: false` → `true`) | `di_verify_test` A2-negative + U3 (2 failing) | exit 1 → CAUGHT |
| M2 | `writeReceipt` returns before persisting (no receipt) | `di_receipts_test` A3 + A3b + U4 (3 failing) | exit 1 → CAUGHT |
| M3 | failure catch returns `success: true` (the issue's core bug) | `di_verdicts_test` A4 (exactly the new test) | exit 1 → CAUGHT |

Each mutant was restored byte-exact from git (`git diff lib/` empty after
restore) and the per-file suite re-ran green (exit 0) — restoration
verified, per the rubric.

## Acceptance-criteria coverage (rubric Q4)

| criterion (issue #974) | test exercising the real entry point | status |
|---|---|---|
| `grep -r "di_command.dart"` returns nothing; fast suite green | `dead_command_gone_test.dart` A1/A1b/U1 (the grep gate, precise to the dead path, live `modular_di_command.dart` excluded) + 74/74 chunked suite | PROVEN |
| `zfa di verify` catches a deliberately dangling `getIt<Missing>()` — tested | `di_verify_test.dart` A2-negative: `MissingUseCase` + `MissingRepository` → `success: false`, message names both classes + `--> fix:` + expected files; CLI smoke: real `dart bin/zfa.dart di verify` → exit 1 with 2 fix hints; clean tree → exit 0 | PROVEN |
| Standalone `di create` writes a receipt; `zfa proof check` green | `di_receipts_test.dart` A3/A3b/U4: receipt `<stamp>-di-<target>.json`, schema `proof.v1`, every sha256 binds on-disk bytes, index receipted + `input.index_files`; `ProofChecker.check().ok == true` after create AND register; dry-run writes nothing | PROVEN |
| A forced generation failure returns `success: false` — tested | `di_verdicts_test.dart` A4: exploding `FileSystem` fake drives the REAL plugin pipeline → `success: false`, message carries the failure, no receipt; A4c: skipped artifacts surface as structured `{target, reason}` warnings; U6: warnings serialized in `toJson()` only when non-empty | PROVEN |

## Test-smell pass (rubric Q2/Q5)

- Every test asserts observable behavior (files on disk, verdict objects,
  exit codes, receipt JSON parsed back through `GenerationReceipt.fromJson`,
  `ProofChecker` verdicts) — no doubles asserted, no internals re-derived.
- The failure-forcing double (`_ExplodingFileSystem`) implements the REAL
  `FileSystem` interface and drives the production write path; the
  assertion is on the capability's public verdict, not the double.
- All tests are hermetic (`Directory.systemTemp` fixtures, no network, no
  Flutter), deterministic, and complete in 00:02 for the whole folder —
  consistent with the suite they join (`test/plugins/di/` per the issue's
  constraint).
- The grep-gate test splits its probe tokens into adjacent string literals
  so the gate cannot self-match the token it enforces.

## Suite, analysis, formatting (real runs, this session)

```text
tools/run_tests_chunked.sh  -> 74/74 chunks OK, 2918 passed / 0 failed
dart analyze                -> 345 issues = baseline 345 (zero new)
dart format --set-exit-if-changed lib/ test/  -> 0 changed, exit 0
dart test test/plugins/di/  -> +29: All tests passed
CLI smoke (real bin/zfa.dart): di verify dangling -> exit 1; clean -> exit 0
```

## Constraints honored

- Simulation-binding emission (spec 893) untouched —
  `simulation_binding_builder.dart` and `simulation_binding_test.dart` are
  byte-identical to base `77e69f24` (verified: `git diff 77e69f24 HEAD --
  lib/src/plugins/di/builders/simulation_binding_builder.dart
  test/plugins/di/simulation_binding_test.dart` is empty).
- Failing-first tests live under `test/plugins/di/` (4 new files).
- One PR for the spec.
