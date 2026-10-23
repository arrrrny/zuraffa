# Assessment — #2010 mock create --certify gate failure contradicts itself

- **Issue:** https://github.com/arrrrny/zuraffa/issues/2010 (labels: bug, spec)
- **Repro anchor:** `da2244020f786fe132baa54957c5d03c594dc367` (master tip at report time)
- **Trigger:** `zfa mock create <Entity> --certify` in a project with no `.dart_tool/`
  (unresolved — `resolveFrameworkRoot(projectRoot) == null`), where the certification
  sandbox's `_unresolvedRun` returns a *structurally-conforms* certification and the
  `--certify` gate (spec #970) then fails its scoped analyze.

## Symptom (confirmed on the unfixed tree, see `red-evidence.txt`)

One run emits three mutually contradictory signals plus a machine-contract lie:

1. `❌ mock certification: <E> does not conform to <E>DataSource` + `--> fix:` lines (the gate refusal)
2. `✅ Success! Created/Modified:` (the generation banner)
3. `📜 mock-certification: … (conforms) → .zfa/receipts/mock-<entity>.json` — and the
   receipt is **persisted on disk** claiming conformance
4. `--json` envelope: `verdict: "pass"` / `exit_class: 0` while the process exits 1

## Root cause (all five points verified in `lib/src/commands/mock_command.dart`, `_runMockGeneration`)

1. **Receipt written before the gate runs** — `MockCertificationService.writeReceipt` is
   called unconditionally after `certify` (before the gate verdict is known), so a later
   gate failure leaves a persisted *conforms* receipt on disk.
2. **Gate failure does not return** — `report.passed == false` prints `❌`, sets
   `exitCode = 1`, then control falls through to the human summary.
3. **`✅ Success!` banner keys off file actions only** — any created/overwritten/updated/
   deleted file prints the banner even after a failed gate.
4. **`📜` tail renders `conforms` from `certification.conformance`** (structural) — never
   from the gate outcome.
5. **`conformanceFailed` ignores the gate** — `generationFailed || !certification.conformance`,
   so the `--json` envelope reports `verdict: pass` / `exit_class: 0` while the process
   exits 1.

## Remediation (chosen per the issue's "fail loudly and consistently" option)

A **failed gate is the run's single signal**. In `_runMockGeneration`:

- Move the receipt write into the gate's **pass branch** (a `--certify` run persists the
  receipt only after the gate passes; the non-`--certify` best-effort structural receipt
  keeps its current write path — no gate runs there, so nothing to contradict).
- Track the gate verdict in a local `gateFailed` and include it in `conformanceFailed`,
  so the `--json` envelope reports `verdict: fail` / `exit_class: 1` on a failed gate.
- Suppress the `✅ Success!` banner and the `📜 mock-certification` tail when the gate
  failed.

No behavior changes on the passing path: a passing gate keeps the banner, the tail, the
persisted receipt, and the pass envelope.

## Scope guard

- No changes to the sandbox, the certifier, or the envelope codec — the defect is the
  orchestration in `_runMockGeneration`.
- No version bump, no unrelated refactors.

## Verification plan (TDD)

- Regression test: `test/plugins/mock/bug_2010_certify_gate_contradiction_test.dart` —
  drives `CliRunner` in-process, gates the failure through the
  `MockCertifier.analyzeRunnerOverride` seam (same `uri_does_not_exist` verdict the real
  analyzer produced in the issue's unresolved-project repro), scaffolds a real temp
  project without `.dart_tool/` so the sandbox takes the same `_unresolvedRun` path.
  - human mode: exit 1, refusal + fix lines present, no banner, no tail, no receipt on disk
  - `--json`: one canonical envelope, `verdict: fail`, `exit_class: 1`, empty receipts, no file
  - passing gate: every existing surface preserved, receipt persisted
- Red on the unfixed tree (see `red-evidence.txt`), green after the fix.
- Full-suite gate: `dart run tools/run_fast_suite.dart` — the repo's sanctioned
  fast-tier entrypoint (the CI `dart_core` lane, serial). A bare `dart test -j 2`
  is documented in `dart_test.yaml` as the #1994 flake generator (a CLI `-j`
  silently overrides the `concurrency: 1` serial invariant) and died mid-suite
  on this loaded host before the switch; the loaded-host window follows the
  #1994 precedent (bounded at 7200s).
