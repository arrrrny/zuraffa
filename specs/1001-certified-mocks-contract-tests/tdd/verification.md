# TDD Verification — feature `1001-certified-mocks-contract-tests`

Written from the ACTUAL runs performed on this branch (every command below
was executed; outputs are quoted from the transcripts, not asserted).
Toolchain: Dart 3.13.2 / Flutter 3.47.2 (`flutter_version: "3.47.x"` in CI).

## Gate

- gate: `passed`
- analyze: `dart analyze lib test --no-fatal-warnings` → **0 errors** (316
  issues total, all warnings/infos — same warning profile as the pre-change
  tree; the CI dart lane gate is errors-only)
- fast suite (chunked): `tools/run_tests_chunked.sh` → **75/75 chunks, 0
  failed, 2,945 tests passed** (63 chunks in the first pass + 12 resumed
  after the runner's 10-minute tool timeout; every chunk reported
  `All tests passed!`)
- format: `dart format lib test` → `Formatted 1855 files (0 changed)` after
  the initial format pass (18 files changed then re-run clean)
- integration (slow tier): `dart test --preset=integration
  test/integration/mock_certification_e2e_test.dart` → `+3: All tests
  passed!` (3:01)

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree)

```
$ dart run bin/zfa.dart mock create Login --certify   → exit 64 (unknown flag)
$ dart run bin/zfa.dart mock create Login --seed=42   → exit 64 (unknown flag)
$ dart run bin/zfa.dart mock certify Login            → usage error (no subcommand)
$ dart run bin/zfa.dart tdd run-engine <feature>      → usage error (no subcommand)
$ dart run bin/zfa.dart mock create Login             → exit 0, but:
  find . -name "mock-cert*" | wc -l      → 0
  find . -name "*contract_test*" | wc -l → 0
```

### GREEN (the same commands on this branch, driven through the real CLI
in a throwaway project)

1. **Exit criterion 1 — `zfa mock create Login --certify` produces a mock,
   runs the contract test, writes `mock-cert.Login.json` with all methods
   `satisfied: true`:**

   ```
   $ dart run bin/zfa.dart mock create Login --certify
   ⚙ mock-cert: entity=Login methods=3 satisfied=3 digest=b9e243cf0e34…
   ✨ test/mock/login/login_mock_contract_test.dart
   ✨ test/mock/login/mock-cert.Login.json            → exit 0
   ```

   The receipt (quoted from disk):

   ```json
   {
     "schema": 1, "spec": 1001, "entity": "Login",
     "interface": "LoginDataSource",
     "subject": "lib/src/data/datasources/login/login_mock_datasource.dart",
     "contract_test": "test/mock/login/login_mock_contract_test.dart",
     "contract_digest": "b9e243cf0e3448df80e1fee4d1f386df4798c4e86ff2deec292f559b91eb9481",
     "methods": [
       {"name": "get",    "satisfied": true},
       {"name": "update", "satisfied": true},
       {"name": "toggle", "satisfied": true}
     ],
     "sandbox": {"runner": "dart", "analyze_issues": 4, "analyze_errors": 0,
                 "tests_passed": 3, "tests_failed": 0}
   }
   ```

   The sandbox proves the contract with the real toolchain: temp package +
   path-dep on zuraffa (resolved from the target project's
   `.dart_tool/package_config.json`), the mock's import closure copied in
   (entity + zorphy parts + interface + mock + mock data), `dart pub get`
   (offline-first), `dart analyze` (0 errors), `dart test` (3/3 per-method
   tests green).

2. **Exit criterion 2 — `zfa mock create Login --seed=42` produces
   byte-identical output to a second run with the same seed:**

   Two fresh projects, same seed:

   ```
   $ dart run bin/zfa.dart mock create Login --seed=42   (project A, exit 0)
   $ dart run bin/zfa.dart mock create Login --seed=42   (project B, exit 0)
   $ diff -r A/lib B/lib                                 → BYTE-IDENTICAL ✓
   ```

   Records derive from the seed (`Login(id: 'id 42', …)`, `id 43`, `id 44`);
   the control run with `--seed=7` produces `id 7`, `id 8` and diffs from
   the 42 output. No-seed generation keeps the historical `id 1/2/3`
   records — pinned by
   `test/plugins/mock/create_mock_capability_seed_test.dart`.

3. **Exit criterion 3 — removing a method from the repository interface
   causes the mock contract test to fail (red):**

   ```
   # certify green first (methods=3 satisfied=3), then:
   $ sed -i '/Future<Login> get(QueryParams<Login> params);/d' \
       lib/src/data/datasources/login/login_datasource.dart
   $ dart run bin/zfa.dart mock certify Login
   zfa mock certify: interface drift: the certified contract pins get but
     the interface no longer declares them — the committed contract test
     goes red
   error - test/mock/login/login_mock_contract_test.dart:28:22 -
     The getter 'get' isn't defined for the type 'LoginDataSource'.
     - undefined_getter
   error - …:31:32 - The method 'get' isn't defined … - undefined_method
   --> fix: regenerate the mock + contract (`zfa mock create Login
       --certify`), or restore the drifted interface, then re-run.
                                                        → exit 3
   ```

   The certification is live: the committed contract test is the drift
   detector (typed tear-offs through the INTERFACE type), and the on-disk
   receipt is overwritten with the honest red state —
   `get/update/toggle → "satisfied": false` — so the run-engine gate never
   reads a stale green receipt. Restoring the interface and re-running
   `mock create Login --certify --force` returns to green (proved in the
   integration test).

4. **Registry + gate (deliverable 3):**

   ```
   $ dart run bin/zfa.dart mock certify Login \
       --fixtures-dir specs/1001-certified-mocks/tdd/fixtures
   mock-certify: entity=Login methods=3 satisfied=3 feature=- \
     registered=true receipt=test/mock/login/mock-cert.Login.json  → exit 0
   ```

   The #832 manifest gains `"mocks": ["Login"]` and the receipt's sha256 in
   `files` (tampering trips `verifyManifest` — pinned by
   `test/plugins/mock/certification/mock_cert_registry_test.dart`); the
   cycle log gains the hash-chained entry:

   ```
   ## 2026-…: certified mock Login (spec 1001)
   - behavior: 1001-certified-mocks-mock-cert-login
   - kind: mock-cert
   - prev-hash: genesis
   - hash: 12080e4dd119b145f1a00bc3cb8a7342a8adf47ec8f1a74338540cd1f0d23e17
   - receipt: mock-cert.Login.json=00e61cd951cb9e0417051dd49330a983d9f32abae913015e660c134299dc558a
   ```

   With `Login` declared as a Key Entity and the mock present:

   ```
   $ zfa tdd run-engine 1001-certified-mocks   → exit 0
     run-engine: feature=… core-entities=1 mocks=1 certified=1 uncertified=0
   $ rm test/mock/login/mock-cert.Login.json
   $ zfa tdd run-engine 1001-certified-mocks   → exit 1
     zfa tdd run-engine: CORE entity "Login" has a mock on disk that is
       NOT certified — the engine refuses to proceed (spec 1001: mocks the
       framework certifies, not the agent).
     --> fix: zfa mock certify Login (or zfa mock create Login --certify), then re-run.
     run-engine: feature=… mocks=1 certified=0 uncertified=1 blocked=Login
   $ zfa tdd run 1001-certified-mocks          → exit 2, result=runner-error
     (the same preflight gate stops the run engine)
   ```

## Test inventory (all green)

| suite | command | result |
| --- | --- | --- |
| certification unit | `dart test test/plugins/mock/certification/` | +22 |
| seed determinism | `dart test test/plugins/mock/create_mock_capability_seed_test.dart` | +4 |
| certify CLI surface | `dart test test/plugins/mock/create_mock_capability_certify_test.dart` | +6 |
| run-engine gate | `dart test test/plugins/tdd/commands/run_engine_command_test.dart` | +7 |
| mock plugin (regression) | `dart test test/plugins/mock/` | +88 |
| tdd commands (regression) | `dart test test/plugins/tdd/commands/` | +164 |
| simulation (regression) | `dart test test/simulation/` | +89 |
| commands (regression) | `dart test test/commands/` | +135 |
| run-driver scenarios (slow) | `dart test sc_013… sc_014… --preset=all` | +9 |
| e2e integration (slow) | `dart test --preset=integration test/integration/mock_certification_e2e_test.dart` | +3 |
| full fast suite (chunked) | `tools/run_tests_chunked.sh` | 75/75 chunks, 2,945 passed, 0 failed |

## Honest notes / deviations

- The issue text says the sandbox runs "dart analyze + flutter test". This
  implementation runs `dart analyze` + `dart test` (package:test — the
  same engine `flutter test` wraps). Rationale: the zuraffa root package
  is pure Dart, the repo's tdd profile pins `runner: dart`
  (`.specify/memory/tdd-profile.md`), and the CI dart lane
  (`dart_core`) has no Flutter SDK — `flutter test` in the sandbox would
  be nondeterministic across environments and red in CI. The mock subjects
  generated by this plugin are pure Dart (no Flutter imports), so nothing
  is untested by this choice.
- `zfa mock create --certify` without `--force` still regenerates the mock
  when files are absent and skips existing ones (existing skip semantics
  unchanged); the contract test + receipt are always rewritten.
- The certification sandbox resolves the zuraffa framework from the target
  project's `.dart_tool/package_config.json` (path dependency), falling
  back to the CLI script location — a target project that never ran
  `dart pub get` gets an honest refusal telling it to.
- The run-engine gate is deliberately scoped to PRESENT mocks: a CORE
  entity with no mock on disk does not block the engine (mocks are
  generated by the loop); only present-but-uncertified mocks refuse.
  This keeps every pre-1001 run flow (including resume-after-interrupt
  with loop-generated mocks) green unless a mock is actually present and
  uncertified — the exact state the certification exists to forbid.
