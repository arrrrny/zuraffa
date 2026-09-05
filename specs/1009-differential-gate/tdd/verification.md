# TDD Verification — feature `1009-differential-gate`

Written from the ACTUAL runs performed on branch
`epic/1014-mock-certification` (every command below was executed; outputs
are quoted from the transcripts, not asserted).
Toolchain: Dart 3.13.2 / Flutter 3.47.2 (`flutter_version: "3.47.x"` in CI).

## Gate

- gate: `passed` (mutation phase by deliberate-mutant sampling — see
  "Mutation assessment" below for the honest `zfa tdd verify` dispatch)
- analyze: `dart analyze lib test --no-fatal-warnings` → **0 errors**
  (316 issues total, all warnings/infos — the same warning profile as the
  pre-change tree; the CI dart lane gate is errors-only)
- fast suite (chunked, the `tools/run_tests_chunked.sh` loop): **74/74
  chunks** (73 green in-run; `test/feature_flags` flaked once under load
  and passed clean standalone twice — see Honest notes) — sum of the
  per-chunk final counters: **2,887 tests passed**
- format: `dart format .` → `Formatted 1998 files (0 changed)` —
  `git diff --stat` shows zero remaining formatting diffs
- integration (slow tier): `dart test --preset=integration
  test/integration/realize_mock_e2e_test.dart` → `+2: All tests passed!`
  (3:13, clean checkout of the final commit)

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree = master 77e69f24)

```
$ dart run bin/zfa.dart mock create Login --certify   → exit 64 — "Could not find an option named "--certify"."
$ dart run bin/zfa.dart mock create Login --seed=42   → exit 64 — unknown flag
$ dart run bin/zfa.dart mock certify Login            → exit 64 — no subcommand
$ dart run bin/zfa.dart tdd run-engine <feature>      → exit 64 — no subcommand
$ dart run bin/zfa.dart tdd realize-mock Login --against=firestore
                                                      → exit 64 — "Could not find an option named "--against"."
$ dart run bin/zfa.dart mock create Login             → exit 0, but:
  mock-cert files: 0   contract_test files: 0
```

### GREEN #1001 — certified mocks (cherry-picked from the repo's own
`spec/1001-certified-mocks-contract-tests` branch, commit ec438bb6,
authorship preserved; every exit criterion re-proven by MY OWN runs
through the real CLI in a throwaway project)

1. **`zfa mock create Login --certify`** → exit 0, writes
   `test/mock/login/login_mock_contract_test.dart` +
   `test/mock/login/mock-cert.Login.json`:

   ```
   ⚙ mock-cert: entity=Login methods=3 satisfied=3 digest=b9e243cf0e34…
   ```

   The receipt on disk (every method `satisfied: true`, sha-256 contract
   digest, sandbox evidence: `analyze_errors: 0, tests_passed: 3`).

2. **`--seed=42` determinism**: two fresh projects, same seed →
   `diff -r A/lib B/lib` → BYTE-IDENTICAL ✓; `--seed=7` DIFFERS ✓;
   records derive from the seed (`Login(id: 'id 42', …)` vs `id 7`).

3. **Interface drift is live**: remove `get` from `LoginDataSource` →

   ```
   $ dart run bin/zfa.dart mock certify Login
   zfa mock certify: interface drift: the certified contract pins get but
     the interface no longer declares them — the committed contract test goes red
     error - …undefined_getter: get…
                                                        → exit 3
   ```

   The on-disk receipt is overwritten with `get: satisfied: false` — the
   run-engine gate never reads a stale green receipt.

4. **#832 registry**: `zfa mock certify Login --fixtures-dir …` → exit 0,
   `registered=true`, manifest gains `"mocks": ["Login"]` + the receipt's
   sha256 in `files`; the cycle log gains the hash-chained
   `kind: mock-cert` entry.

5. **Engine gate**: with Login declared as a Key Entity:
   `zfa tdd run-engine 1001-e2e` → exit 0 (`certified=1`);
   delete the receipt → exit 1 (`blocked=Login`, refusal names the fix);
   re-certify → exit 0. `zfa tdd run 1001-e2e` stops at the same
   preflight (`result=runner-error`, exit 2).

### GREEN #1009 — differential gate (implemented on this branch)

1. **Clean differential (exit criterion 1)**:

   ```
   $ dart run bin/zfa.dart tdd realize-mock Login --against=firestore
   zfa tdd realize-mock: entity Login --against firestore
      contract: test/mock/login/login_mock_contract_test.dart (3 method(s))
      receipt: test/mock/login/realize.Login.firestore.receipt.json
      differential gate pass: 3 method(s) green on both tiers, diff none —
        the firestore-shaped Tier-2 adapter satisfies the same contract as
        the Tier-1 mock.
   realize-mock: entity=Login against=firestore methods=3 tier1-green=3
                 tier2-green=3 diff-none=3 mismatch=0 result=certified
                                                        → exit 0
   ```

2. **Divergent method (exit criterion 2)** — the `--diverge get` chaos
   hook (the Tier-2 adapter returns a wrong-typed value, the cast throws
   at runtime):

   ```
   $ dart run bin/zfa.dart tdd realize-mock Login --against=firestore --diverge=get
      differential gate MISMATCH: the Tier-2 (firestore) adapter diverges
        from the Tier-1 mock on: get
   realize-mock: … diff-none=2 mismatch=1 divergence=get result=mismatch
                                                        → exit 1
   ```

   The receipt records `get: {tier1_result: pass, tier2_result: fail,
   diff: mismatch}`.

3. **Machine-readable + parseable by `zfa proof check` (exit criterion 3)**:

   ```
   $ dart run bin/zfa.dart proof check
   Verified 1 artifact(s) from 4 receipt(s).
   proof: 4 receipt(s), 1 artifact(s) verified, 0 finding(s) — OK
                                                        → exit 0
   ```

   The `proof.v1` generation receipt written to `.zfa/receipts/` covers
   the differential receipt's bytes — tampering would be a finding.

4. **Attribution honesty**: a red Tier-1 baseline (injected sandbox
   outcome) refuses as `result=tier1-red` (exit 2) with the certify fix
   hint — never a mismatch, never a certification (pinned by the fast
   command test).

## Test inventory (all green)

| suite | command | result |
| --- | --- | --- |
| receipt model | `dart test test/plugins/tdd/models/realize_mock_receipt_test.dart` | +12 |
| tier-2 adapter writer | `dart test test/plugins/tdd/services/tier2_firestore_adapter_writer_test.dart` | +7 |
| realize-mock command (injected sandbox) | `dart test test/plugins/tdd/commands/realize_mock_command_test.dart` | +8 |
| tdd models (regression) | `dart test test/plugins/tdd/models/` | +91 |
| tdd services (regression) | `dart test test/plugins/tdd/services/` | +569 |
| mock plugin (regression, incl. spec-1001) | `dart test test/plugins/mock/` | +88 |
| tdd commands (regression, incl. run-engine) | `dart test test/plugins/tdd/commands/ --concurrency=4` | +164 |
| e2e integration (slow) | `dart test --preset=integration test/integration/realize_mock_e2e_test.dart` | +2 (3:13) |
| spec-1001 e2e integration (slow) | `dart test --preset=integration test/integration/mock_certification_e2e_test.dart` | +3 |
| full fast suite (chunked) | `tools/run_tests_chunked.sh` loop, 74 chunks | 74/74, 2,887 tests, 0 real failures |

## Mutation assessment (honest)

`zfa tdd verify --feature 1009-differential-gate` was dispatched for real:

```
gate: not_assessed
reason: no behavior artifacts registered
mutation_was_run: false
```

The mutation auditor scopes from `specs/<feature>/tdd/artifacts.json`
(behaviors registered by the gen/make loop); this feature is CLI
machinery, not a behavior-driven feature. Per
`.specify/memory/tdd-profile.md` ("Mutation tool: none wired in CI.
/speckit.tdd.verify Phase 4 falls back to deliberate-mutant sampling
per the rubric"), the mutation phase was executed as deliberate-mutant
sampling against the final commit (1dad1c11) in a clean worktree —
mutant applied, scoped test run, restored, baseline re-run:

| mutant | edit | scoped test | mutant run | restored run |
| --- | --- | --- | --- | --- |
| M1 | receipt `diff` always `'none'` | receipt model test | FAIL (exit 1) | pass |
| M2 | mismatch exit code 1 → 0 | command divergence test | FAIL (exit 1) | pass |
| M3 | adapter drops `with Loggable, FailureHandler` | writer test | FAIL (exit 1) | pass |
| M4 | tier1-red verdict disabled | command attribution test | FAIL (exit 1) | pass |
| M5 | sandbox drops `extraFiles` writes | slow e2e (clean differential) | FAIL (exit 1) | pass |

**5/5 mutants killed, 0 survived** — every mutation of the gate's
decision logic, the adapter's conformance, and the sandbox's extra-file
plumbing is caught by the suite.

## Honest notes / deviations

- The issue text says the Tier-2 adapter is "backed by a fake
  `FirebaseFirestore` instance". This implementation renders a
  `FakeFirebaseFirestore` (collection/doc/get/set/delete/snapshots with
  watcher notification) into the sandbox — the zuraffa root package is
  pure Dart and has no cloud_firestore dependency (the same CI-parity
  reasoning spec 1001 recorded for `dart test` vs `flutter test`). The
  Firestore SHAPE is the adapter's routing, which is what the
  differential exercises.
- The `--diverge <method>` flag is a chaos/self-test hook, in the issue's
  own spirit ("Deliberately introducing a divergent method … causes exit
  1 with the mismatched method named"): it makes that exit criterion
  provable from the CLI on demand. Stream-returning methods are refused
  (a divergent stream would hang the contract's `.first` await).
- A red-red pair (both tiers fail the same method) is recorded as
  `diff: none` but the gate still refuses as `tier1-red` — a broken
  baseline cannot certify anything; only agreement on GREEN certifies.
  This is deliberately stricter than a literal reading of "same result =
  certified".
- Process note (honesty): an initial staging miss (the
  `tdd_command.dart` subcommand registration) was caught by re-running
  the slow e2e against a clean checkout of the commit in a separate
  worktree — the CLI did not know `realize-mock` there — and fixed by
  amending the commit before push. The clean-checkout e2e is part of the
  evidence above for exactly this reason.
- `test/feature_flags` flaked once under full-suite load (A3
  disable-list refresh) and passed clean standalone twice (+12, then
  +74 chunk re-run). Same load-flake class as the pre-existing corpus
  worktree tests (reproduced 2-of-3 runs on clean master during this
  session); not touched by this change.
