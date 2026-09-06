# Bug Assessment: PR 1210 dart_core red — 3 failures inherited from master (#1206), 1 genuine PR regression

- **Slug**: pr-1210-ci-red
- **Created**: 2026-09-06
- **Source**: pasted CI output from PR 1210 (`arrrrny/zuraffa#1210`, branch `spec/1109-make-engine-preset` → `master`, head `c7d3de27`)
- **Verdict**: valid
- **Severity**: high (master itself is red; the PR's own failure blocks its merge)

## Report (verbatim or summarized)

User report: "check the PR 1210, master is PRISTINE green but this PR has failing tests" — 4 failing tests in the `dart_core` job (5401 passed / 4 failed / 1 skipped):

1. `test/commands/engine_check_command_test.dart` — "exits 0 on a clean engine slice" — Expected `<0>`, Actual `<1>`; stdout ends with `❌ Missing engine receipt: no engine.receipt.json for "Login" under specs/<feature>/tdd/`
2–4. `test/regression/issue_891_example_meta_resolution_test.dart` — 3 tests failed: `dependency_overrides` is `null` in `example/pubspec.yaml` ("Expected: <Instance of 'Map'> Actual: <null>").

**Premise correction (verified against CI):** master is NOT green. Master run `34027280435` at `350e2d8e` (the #1206 merge) is `dart_core: failure` — **5381 passed / 3 failed**, and the 3 failures are **exactly the same issue_891 tests**. The last green master was `c7cf331a` (run `34026515183`), the commit immediately before the #1206 merge. CI for PRs (`pull_request` event) checks out the **merge ref** (PR head merged into master), so the PR inherits master's fresh breakage.

## Symptom

Two independent failures:

- **A (master regression, not the PR's):** #1206 (`63ebe917`, "fix(1189)") deliberately dropped `dependency_overrides: meta: ^1.18.3` from `example/pubspec.yaml` (Flutter 3.47.x re-pinned meta) but left `test/regression/issue_891_example_meta_resolution_test.dart` asserting the override **must exist**. Tests 1–3 of that file now fail on every tree containing master's #1206; test 4 ("root pubspec analyzer constraint") still passes because the analyzer floor (14.0.0) is ≥ 13.1.0.
- **B (genuine PR regression):** PR 1210 adds an engine-receipt leg to `zfa engine check` (`verifyReceipt: true` hard-wired in `EngineCheckCommand.run()`), but the pre-existing spec-1002 test "exits 0 on a clean engine slice" writes the canonical Login slice **without any receipt** (0 mentions of "receipt" in the file). The missing-receipt finding flips exit code 0 → 1.

## Reproduction

Failure A (already reproducing on master):
1. Check out master `350e2d8e` (or the PR merge ref).
2. `dart test test/regression/issue_891_example_meta_resolution_test.dart`
3. Tests 1–3 fail: `doc['dependency_overrides']` is `null`.

Failure B:
1. Check out PR head `c7d3de27`.
2. `dart test test/commands/engine_check_command_test.dart --plain-name "exits 0 on a clean engine slice"`
3. Exit code 1 with the missing-receipt finding (matches CI stdout).

## Suspected Code Paths

Failure B (PR):
- `lib/src/commands/engine_command.dart` (PR diff, ~line 112-116) — `EngineCheckCommand.run()` now passes `verifyReceipt: true` unconditionally.
- `lib/src/engine/engine_checker.dart:169-187` (PR) — new receipt leg emits `EngineFindingCode.missingReceipt` when `EngineReceiptWriter.loadV2Receipt()` returns null.
- `lib/src/engine/engine_receipt_writer.dart:229` (PR) — `loadV2Receipt` resolves `specs/<feature>/tdd/engine.receipt.json` (by `--feature`, pinned feature, or scan-by-entity).
- `test/commands/engine_check_command_test.dart:87-92` — untouched by the PR; fixture writes no receipt → now fails.

Failure A (master):
- `example/pubspec.yaml` on master — override section replaced by the #1189 comment ("now resolves with ZERO dependency_overrides").
- `test/regression/issue_891_example_meta_resolution_test.dart` — byte-identical on master and the PR (`git diff c7d3de27 master` on the file is empty); still asserts the override exists.

## Root Cause Hypothesis

High confidence for both, backed by CI logs and git archaeology:

- A: #1206 changed the contract (override dropped) but not its regression test. The test file's own 4th test even anticipates the flip ("flip this guard then"), but the drop happened via the Flutter meta re-pin + #1189 resolution, not the analyzer floor dropping below 13.1.0, so the coded condition never flipped.
- B: PR 1210 tightened the `engine check` contract (receipt mandatory) and added new-leg tests (`test/engine/engine_check_v2_test.dart`, `test/engine/engine_receipt_v2_test.dart`) but did not sweep the pre-existing command-level contract test.

## Proposed Remediation

**Preferred — Failure B (fix belongs in PR 1210):** in `test/commands/engine_check_command_test.dart`, make `writeCanonicalSlice()` (or at least the "exits 0" test) also write a valid v2 receipt at e.g. `specs/000-default/tdd/engine.receipt.json`:

```json
{
  "schema": "engine.v1",
  "entity": "Login",
  "methods": [{"name": "get", "mock_certified": true, "mock_class": "LoginMockDataSource"}],
  "source_files": ["lib/src/data/datasources/login/login_remote_datasource.dart"]
}
```

(keys per `EngineReceiptMethod.toJson`, `lib/src/engine/engine_models.dart:189`; the checker only requires the file to exist and no method with `mock_certified: false`). Keep the broken-slice test expectations as-is; additionally add/keep a case asserting a missing receipt exits 1 — the PR's v2 suite likely covers this, but the command-level exit-code contract should keep both polarities.

**Preferred — Failure A (fix belongs on master, independent of the PR):** rewrite `test/regression/issue_891_example_meta_resolution_test.dart` to assert the NEW contract: `example/pubspec.yaml` has **no** `dependency_overrides` (or none for `meta`), with the resolution proof delegated to `tools/flutter_smoke_gate.sh` / the `flutter_consumer_smoke` CI job that #1206 added. Flip the 4th test's guard accordingly. Ship as a small master fix PR (or cherry-pick into 1210 if the maintainer prefers one red→green hop — separate master fix is cleaner ownership).

**Alternatives:**
- For B: revert `verifyReceipt: true` to opt-in (flag-gated) — rejected: the mandatory receipt is the PR's stated #1109 contract; the test fixture should follow the contract, not the reverse.
- For A: keep the test and re-add the override — rejected: directly contradicts #1206's deliberate #1189 fix and its non-vacuous smoke gate.

**Files likely to change:**
- `test/commands/engine_check_command_test.dart` (PR 1210)
- `test/regression/issue_891_example_meta_resolution_test.dart` (master)

**Tests to add or update:**
- "exits 0 on a clean engine slice" green again with receipt present (PR 1210)
- Optional: command-level "missing receipt exits 1" polarity test (PR 1210)
- Rewritten 891 guard asserting zero overrides + pointer to the smoke gate (master)

## Risks & Considerations

- The 891 rewrite must not silently weaken protection: the new assertion ("no meta override, resolution still closes") is only enforced per-run by the flutter_consumer_smoke job; keep the dart_core test as the file-shape guard.
- PR 1210's diff also touches `make_command.dart`, `preset_registry.dart`, `mock_certifier.dart`, `generator_config.dart` and 5 new compile tests — a rebase onto post-#1206 master is needed anyway before merge (merge-base is `42840d81`, master has moved).
- CI `test` / `analyze` / `format` / smoke jobs all pass on the PR; only `dart_core` is red.

## Open Questions

- None blocking. Ownership split confirmed: 1 failure is the PR's to fix; 3 are master's and should not block the PR once the merge base includes the 891 test fix.
