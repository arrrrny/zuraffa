# Verification — 1691-unit-scaffold-entity-param-import

- **Date**: 2026-09-17 (review-fix session)
- **Branch**: `fix/1691-unit-scaffold-entity-param-import`
- **Revision verified**: `b1c1d2ff` (reviewed revision) + the review-fix
  commit on top; the red run reverts ONLY
  `lib/src/plugins/tdd/services/behavior_test_writer.dart` to its parent
  `8861d41d`.
- **Scope audited**: `spec.md` (SC-1..SC-5), `plan.md`, `tdd/test-list.md`,
  `tdd/cycle-log.md`, the changed code
  (`lib/src/plugins/tdd/services/behavior_test_writer.dart`,
  `lib/src/plugins/tdd/services/unit_contract_shape.dart` — docs only), and
  the changed regression test.

## Verdict

VERIFIED for this spec's fix surface. The repo lane (SC-2, SC-3, SC-4 and
the regression half of SC-1) was re-run in this session on the branch under
review; the end-to-end probe lane (SC-1's `verify-red` certification and
SC-5) is inherited evidence from the `login_probe` verification project,
preserved verbatim in `tdd/cycle-log.md` and marked as such below.

| id | criterion | verdict | evidence |
|----|-----------|---------|----------|
| SC-1 | login_probe repro imports param + return (param first), helper renders the lifted type, `verify-red` certifies `assertion`/`certified=true` | PASS | repo half re-run: `T-1691` red→green in `tdd/cycle-log.md` (G1 pins param + return, param-first); probe half: probe `U1 (red)` entry, `classification: assertionFailure` with the lifted `LoginParams` param — the pre-fix tree is the `compile-error` classification |
| SC-2 | entity param + scalar return imports the param entity | PASS | `T-1691` green: G2 in `spec_1691_..._test.dart` 3/3 |
| SC-3 | scalar-only contract keeps the legacy template byte-for-byte | PASS | `T-1691` green: G3 (no `_argN()`, no `domain/entities/` import); the red run shows G3 green even against the unfixed writer — the scalar path never regressed |
| SC-4 | the unit-scaffold regression suites stay green, unmodified | PASS | `00:10 +41: All tests passed!` — spec_1691 3/3, bug_1420 3/3, bug_1513 3/3, unit_contract_shape_1489 20/20, subject_provenance_1565 12/12; `dart analyze` on the touched files: `No issues found!`; `dart format --set-exit-if-changed`: 0 changed |
| SC-5 | the zcalc probe (scalar params) certifies an honest red unchanged | PASS (inherited) | probe-lane run recorded with the fix (`zfa tdd verify` gate `pass`, mutation score 1.0, restoration verified — probe sections below); repo-lane corroboration is G3's byte-stability pin |

## 1. Red → green (repo lane, re-run this session)

Source: `tdd/cycle-log.md`, `T-1691` cycles. Nothing below is copied from an
earlier run.

- **Red** — command `dart test
  test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart`
  against the pre-fix writer: exit 1, `+1 -2`. G1 and G2 fail on the import
  claim for the RIGHT reason — the failure dump shows the generated test
  rendering `LoginParams _arg0()` with only the `user_session` import (the
  exact #1691 compile-error source). G3 (scalar-only) passes, so the red set
  is exactly the two import claims and nothing else.
- **Green** — the same test plus the four sibling suites on this branch:
  exit 0, `00:10 +41: All tests passed!` (per-suite counts above).
- **Gates** — `dart analyze
  lib/src/plugins/tdd/services/unit_contract_shape.dart
  test/plugins/tdd/commands/spec_1691_unit_scaffold_entity_param_import_test.dart`
  → `No issues found!`; `dart format --output=none --set-exit-if-changed` on
  the same two files → `Formatted 2 files (0 changed)`.

## 2. Probe lane (inherited evidence, `login_probe`)

The `U4`/`U5` rows of `tdd/test-list.md` are end-to-end behaviors that need a
real verification project; they cannot be re-run from this repo's checkout
(no probe project here). Their evidence is the probe app's own cycle log,
preserved verbatim in `tdd/cycle-log.md`, produced by `zfa tdd run 001-login`
/ `zfa tdd verify --feature 001-login` inside
`/home/z/my-project/probe/login_probe` with the FIXED zuraffa source tree:

- `U1 (red)` — `classification: assertionFailure`; the failure is
  `Expected: <Instance of 'UserSession'>` vs `Actual: UnimplementedError:
  provide a representative argument for subject_u1 (declared param 0:
  LoginParams)`. The lifted param type compiled and the failure landed on the
  assertion — the SC-1 transition (`compile-error` → honest red).
- Mutation audit at the probe feature's scope — `gate: pass`, `killed: 1`,
  `survived: 0`, `timed_out: 0`, `mutation_score: 1.0000`,
  `restoration_verified: true` (the probe-run heredoc detail lives with the
  probe project; the numbers quoted by the PR description are these).
- The zcalc probe (scalar-only contract) kept the probe template
  byte-identical with the same honest-red classification — SC-5, recorded in
  the PR description's verification section.

## 3. Review-fix delta (this session)

The revision reviewed at `b1c1d2ff` carries three findings; this session's
commit applies all of them (doc/assertion only — no behavior change):

1. `unit_contract_shape.dart` — `entityImports` / `returnEntityImports` doc
   comments updated to the post-#1691 contract (both writers emit the full
   set; `returnEntityImports` has no writer consumer left). Doc-only; lift
   semantics and the constructor are untouched.
2. `spec_1691_..._test.dart` — the three import assertions pin the emitted
   `import 'package:fixture_app/src/domain/entities/<entity>/<entity>.dart';`
   directive instead of a bare path substring (the `unit_contract_shape_1489`
   suite's idiom).
3. `spec_1691_..._test.dart` — G3's `reason: out` → `reason: testContent`
   (the assertion is about the generated body, not the generator's stdout).
   The now-unused `out` binding was dropped so `dart analyze` stays clean.

## 4. Limits / not covered

- The probe lane was NOT re-executed in this session (no Flutter probe
  project in this checkout) — its numbers are inherited and labeled as such
  in `tdd/cycle-log.md` §probe.
- The full `dart test test` sweep was not run; the verification is scoped to
  the suites the change can reach (the five above), per the repo's
  changed-files protocol.
- `test/plugins/tdd/services/behavior_test_writer_test.dart` (slow-tagged)
  carries one pre-existing red (bug #871) that reproduces identically on
  `origin/master`; it is untouched by this change and was not re-run here.
