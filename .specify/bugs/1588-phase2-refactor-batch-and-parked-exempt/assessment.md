# Assessment — BUG 1588

## Code map (verbatim reading, branch `master` @ e260a59b)

- `lib/src/plugins/tdd/commands/run_driver_core.dart` — phase 2b (lines
  849-918) loops per green row and calls `_driveBehavior(steps: ['refactor'])`;
  `_driveBehavior` (line 1457) spawns every step through `StepRunner.run`
  (line 1533). Phase-2a (780-847) and the baseline capture 6b (594-687)
  surround it.
- `lib/src/plugins/tdd/services/step_runner.dart` — `run()` builds argv
  `tdd <step> <id> --feature <f> --project <root> [--suite-baseline <p>]
  [--timeout <m>]` (lines 288-320). #922 already hands `--suite-baseline`
  to make AND refactor spawns (line 305).
- `lib/src/plugins/tdd/commands/refactor_command.dart` — the per-spawn
  pipeline: preflight (line ~325 `print('zfa tdd refactor: preflight suite')`),
  pass registry (line ~457 `RefactorPasses(...).run()`), re-proof (line ~617
  `runner.runSuite(...)`; full suite when `libChanged` is empty, line 613).
  #922 baseline tolerance lives in the `preflight.exitCode != 0` branch
  (line ~387) and the re-proof verdict (line ~691): `SuiteGuard.diff`
  newFailures — toleration requires the failure to be IN the baseline.
- `lib/src/plugins/tdd/services/pass_registry_tracker.dart` —
  `specs/<feature>/tdd/pass-registry.json`, append-only changed-file
  entries; `coveringTestsFor` scopes the re-proof (spec 069 T001).
- `lib/src/plugins/tdd/models/artifact_record.dart` — registry rows carry
  `behaviorId`, `testPath`, `subjectPath` — the id -> covering-test map the
  exemption needs.
- `lib/src/plugins/tdd/services/tree_snapshot.dart` — `entries`
  (path -> `file:<sha256>`) is public: a stable whole-tree digest is
  derivable for the batch ledger.

## Root causes

1. **Economics**: phase-2b spawns one full refactor pipeline per green
   behavior. Nothing carries "the pass already ran for this feature's phase"
   into the next spawn — the pass registry records changed FILES but not a
   reusable gate verdict, and the re-proof runs even when `applied == 0`.
2. **Coupling**: the parked BLOCKED behavior's red contract test is not in
   the run baseline (the file is created by gen in phase 1, AFTER the 6b
   baseline capture), so `SuiteGuard.diff` reports it as a NEW failure and
   the preflight refuses for every green behavior.

## Remediation (design)

A. **Pass-batch ledger** (new `pass_batch_ledger.dart` +
   `refactor_command.dart`): a driver-only `--pass-batch` flag opts the
   spawn into `specs/<feature>/tdd/pass-batch.json`. The ledger keys on
   (suite template, baseline-file content hash, exempt id set, lib/ tree
   digest, test/ tree digest). On a hit, the invocation inherits the gate:
   NO preflight, NO pass registry, NO re-proof — clean no-op, honest
   evidence line, exit 0. On a miss/stale/corrupt file the full pipeline
   runs and the ledger is written on the green path. Flag-less standalone
   invocations never touch the ledger (absolute-green contract preserved).

B. **Parked exemption** (`refactor_command.dart`): a driver-only
   `--exempt-behaviors id1,id2` flag. The command maps ids to registered
   test paths via `ArtifactRegistry` (fail-open) and removes those tests
   from the preflight/re-proof failing sets BEFORE the verdict:
   - with a usable baseline: newFailures computed after exclusion (#922
     economics extended);
   - without a baseline: toleration only when EVERY failure is an exempt
     test (never tolerates a non-exempt failure — safe fallback kept).

C. **Driver phase-2b loop** (`run_driver_core.dart`): the pass computes the
   lane's blocked ids and hands `--pass-batch --exempt-behaviors <ids>` to
   the phase-2b refactor spawns through a new optional `StepRunner.run`
   parameter (refactor-only call sites; gen/verify-red/make call sites and
   phase-1 refactor spawns unchanged). Per-behavior spawns, state
   transitions, deferral and skip semantics stay byte-identical.

## Constraints honored

- make step: untouched. State machine: untouched. Suite runner: untouched.
- The full gate still exists: `zfa tdd verify`'s preflight and the nightly
  corpus lane run the full suite; the ledger only removes REDUNDANT
  re-proofs of a byte-identical tree within one phase-2 pass (the spec 069
  T001 frequency-engineering argument verbatim).

## Risk notes

- Ledger staleness across resume runs: a fresh run re-captures (or skips)
  the baseline; the baseline content-hash key mismatches -> one full
  pipeline run rewrites the ledger -> remaining behaviors inherit. Bounded,
  honest.
- Flaky tests: the ledger requires byte-identical lib/ AND test/ trees; the
  feature-completion full gate still runs. Same stability assumption the
  existing scoped re-proof makes.
