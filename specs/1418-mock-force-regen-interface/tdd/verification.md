# Verification: 1418-mock-force-regen-interface

Date: 2026-09-15 · Branch: `feat/1418-mock-force-regen-interface`

## Method

Every number below is from a real run in this checkout: `dart test`
(3.13.4 stable), `dart analyze`, `dart format --set-exit-if-changed`,
and — for the E2E proof — the REAL CLI compiled through the sanctioned
no-JIT launcher (`scripts/zfa`, AOT cache `.dart_tool/zfa_cli_bin/zfa_exe`)
driving a scratch consumer project (`/tmp/sc001_proj`, path dependency on
this repo, real `dart pub get`). Kernel cache cleaned before every suite
(`rm -rf .dart_tool/test/`, `rm -f $TMPDIR/dart_test.kernel.*`). Nothing
is asserted from reading code alone. The red→green discipline: the
behavior tests were run and observed FAILING on the pre-fix tree (cycle 1
RED evidence in `tdd/cycle-log.md`), the implementation landed, and every
suite below was re-run and observed passing.

## Red evidence (pre-fix tree, real output)

`dart test test/plugins/mock/mock_builder_1418_force_interface_test.dart`
→ `+6 -4` — four behavior tests FAILED, each with `Expected: not null /
Actual: <null>` on the interface's ledger entry (the create-if-absent
guard never invoked the interface writer):

- A1 force-interface-rewritten · A2 pair-conformance · U1 dry-run ledger ·
  U3 repo-path stability.

The four unchanged-behavior guards (A3 non-force byte-identical, A4
absent-interface emitted, U2 revert precedence, U4 idempotence) passed
pre-fix — they pin contracts the fix must not move.

`dart test test/utils/zuraffa_barrel_exports_mock_surface_test.dart` →
LOAD failure (compile red: `filterMock` did not exist).
`dart test test/plugins/mock/mock_datasource_builder_hide_mock_barrel_test.dart`
→ `+1 -1`: the diverged-barrel case FAILED with the emitted
`import 'package:zuraffa/mock.dart';` carrying the unverified hide — the
#1418 asymmetry, live at emission level.

## Green evidence (post-fix)

| suite | result |
| --- | --- |
| `test/plugins/mock/mock_builder_1418_force_interface_test.dart` (A1–A4, U1–U4) | 10 passed |
| `test/utils/zuraffa_barrel_exports_mock_surface_test.dart` (A5 a–d, U5 ×4) | 8 passed |
| `test/plugins/mock/mock_datasource_builder_hide_mock_barrel_test.dart` (A6 ×2) | 2 passed |
| `test/plugins/mock/` full plugin suite (incl. #1570 A1–A5/U1–U6 + U4 precedence, capability, certify gate, builder, verify, explain) | all passed |
| `test/utils/zuraffa_barrel_exports_test.dart` (#1176/#1530 pins) | all passed |
| `test/utils/framework_export_surface_test.dart` | all passed |
| `test/plugins/datasource/barrel_hide_unverified_1530_test.dart` | all passed |
| `test/regression/issue_942_entity_name_collides_framework_export_test.dart` (byte-exact hide pin + entity preflight) | 6 passed |
| **Full regression sweep (all of the above in one run)** | **238 passed / 0 failed** |

One honest mid-run correction, recorded in the cycle log: the #942 suite
initially went red because its FIXTURE zuraffa package shipped no
`lib/mock.dart`; under the new (correct) verification target the mock
surface was empty. The suite's assertion is the #942 contract and was NOT
changed; the fixture was extended to mirror the real package layout (bare
re-export), after which the byte-exact pin passes.

`dart analyze` over the five changed lib files: **No issues found!**
`dart analyze` over the four changed test files: **No issues found!**
(after fixing three `no_leading_underscores_for_local_identifiers` infos
in the new tests). `dart format --set-exit-if-changed lib test`: **0
changed** (CI format gate).

## E2E proof (real CLI, scratch consumer project — the issue's verbatim repro)

Scratch project: `pubspec.yaml` with `zuraffa: path:` dependency, real
`dart pub get`, entity `Deal` seeded, then the two issue commands through
the AOT-compiled CLI:

1. **Step 1** — `scripts/zfa mock create Deal --methods list` → exit 0;
   interface declares `Future<List<Deal>> list(NoParams params)`; receipt
   `mock-cert:deal@a518d89b (DRIFT)` — the issue's pre-state reproduced
   exactly.
2. **Step 2** — `scripts/zfa mock create Deal --methods getList --certify
   --force` → **exit 0**:
   `✅ mock certification: Deal conforms to DealDataSource
   (mock-cert:deal@cd05085d)`, receipt `(conforms)` — previously this
   exact command dead-ended with
   `❌ mock certification for Deal failed — unsatisfied: list` and
   `Missing concrete implementation of 'DealDataSource.list'`.
3. **Regenerated interface** declares
   `Future<List<Deal>> getList(ListQueryParams<Deal> params)` — the stale
   `list(NoParams)` member is gone; the pair cannot drift under `--force`.
4. **Scoped `dart analyze` over `lib/src/data/datasources/deal/`** →
   **No issues found!** (the issue reported 7 issues / 1 error on the
   drifted pair).
5. **Hide emission**: the regenerated datasource files carry NO `hide`
   combinator for `Deal`/`DealPatch` (not exported by the barrels) —
   `undefined_hidden_name` cannot fire from this output.

Environment note, recorded honestly: the first Step-2 attempt failed with
`dart pub get failed: ProcessException: No such file or directory` — the
shell had lost the Dart SDK from PATH, so the certifier's `dart pub get`
spawn could not resolve. Harness environment, not a product defect: with
PATH restored the same command passed (evidence above). The repro was
then re-run FROM SCRATCH (fresh project, both steps) to produce the
recorded evidence.

## Acceptance criteria → evidence

| # | criterion | verdict | evidence |
| --- | --- | --- | --- |
| 1 | `--force` regenerates both interface and mock when `--methods` changes | **PROVED** | A1 + E2E step 2/3 (interface rewritten, action `overwritten`) |
| 2 | `undefined_hidden_name` eliminated from generated datasource files | **PROVED** | A5/A6 + E2E step 4/5 (scoped analyze clean, no unverified hides) |
| 3 | Certification passes on a `--force`-regenerated pair with changed methods | **PROVED** | A2 (structural oracle) + E2E step 2 (`conforms`, exit 0) with ZERO certification-file changes |
| 4 | No regressions on existing mock creation (non-force path) | **PROVED** | A3 (byte-identical interface, in-sync mock skipped) + full sweep 238/238 incl. #1570 U4 precedence, #1530, #942 |

## Mutation evidence (7 mutants, all killed — 0 survived, 0 timeout)

Each mutant was applied to the working tree, the targeted suite run, and
the file restored (`git checkout --`); suite state re-verified clean
afterwards.

| mutant | change | result |
| --- | --- | --- |
| M1 | guard drops `config.force` (pure create-if-absent restored) | **KILLED** — A1, A2, U1, U3 fail (`+6 -4`) |
| M2 | guard drops `!config.revert` | **KILLED** — U2 fails (`+9 -1`) |
| M4 | guard drops `!exists` disjunct | **KILLED** — A4 fails (`+9 -1`) |
| M5 | mock surface unions the zuraffa set unconditionally (ignores re-export combinators) | **KILLED** — A5(c) fails (`+7 -1`) |
| M6 | `filterMock` returns its input unfiltered | **KILLED** — A5(a) fails (`+3 -5`) |
| M7 | `filterMock` always returns empty | **KILLED** — A5(b) fails (`+3 -5`) |
| M8 | mock datasource emission reverts to the zuraffa-surface filter | **KILLED** — A6 diverged-barrel case fails (`+1 -1`) |

(M3 from the test list was folded into M1 — the same restored pre-fix
guard.)

## Test-smell rubric (self-check)

- No test asserts on implementation private state — all assertions run
  through public builder/resolver APIs, ledger actions, or file bytes.
- No conditional/sleep-based flakiness: everything is synchronous file
  state or AST extraction; no `expectLater` timeouts.
- The conformance oracle (A2) reuses the certification's own primitives
  (`MethodExtractor.extractMethodsFromInterface`,
  `MockStalenessDetector.detectMockStaleness`) so the test cannot
  disagree with the gate it predicts.
- Both new suites seed isolated temp trees and reset the resolver seam
  (`ZuraffaBarrelExports.reset()`) in `tearDown` — no cross-test state.

## Residuals (recorded, out of scope by the hard constraint)

- **`deal_mock_contract_test.dart` `unused_import` (deal_mock_data.dart)**:
  reproduced in the E2E project (exactly one warning at 14:8 after giving
  the scratch project a `test` dev_dependency). Emitted by
  `lib/src/plugins/mock/certification/mock_contract_test_writer.dart` —
  certification-owned output. FR-008 forbids touching certification
  logic in this PR; recorded for a certification-scoped follow-up.
- The scratch project's unrelated first-round `undefined_function`
  errors were its missing `test` dev_dependency (environment), resolved
  before the residual check above.

## Honest limits

- The full-repo test suite was NOT run end-to-end (only the changed-file
  neighborhood per the cloud-agent verify protocol: mock lane, utils,
  datasource hide suites, #942 regression, plus `dart analyze`/format
  gates); unrelated pre-existing failures outside these lanes, if any,
  were not surveyed.
- The E2E scratch project is a pure-Dart consumer; a Flutter-target
  consumer (flutter_test pinning) was not exercised — out of scope for
  the Dart-only mock create path under test.
