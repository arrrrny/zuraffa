# Cycle Log — tdd-external-service-simulation (bug #832)

Branch: `fix/832-tdd-external-service-simulation` · Base: master `17a40434` · Dart SDK 3.13.3 (stable)

## Cycle: B-832 (red → green → refactor → verify)

### RED (pre-fix, real run)

State at master `17a40434`: no `simulate` command is registered on the CLI, no
simulation adapters exist anywhere under `lib/`, no fixture infrastructure and
no network-isolation guard. The RED run (`dart test test/simulation` against
the pre-fix source) is dominated by the honest compile-level proof of absence:

- command: `dart test test/simulation --reporter compact`
- exit: 1 — `+0 -10: Some tests failed.`
- every suite failed to load: `Error when reading 'lib/src/simulation/network_isolation_guard.dart': No such file or directory` and the matching undefined-symbol errors for `FirebaseAuthAdapter`, `VendureAdapter`, `RestAdapter`, `AdMobAdapter`, `OtelAdapter`, `SimulationWorld`, `SimulationFixtures`, `FixtureRegistry`, `SimulateCommand` (103 missing-symbol/error markers in the saved log)
- the CLI-registration tests loaded and failed on behavior: `zfa simulate` is an unknown command — the auto-generated help output (no ` simulate ` entry) proves the command surface is absent
- evidence: `coverage/832-red/red_full.log` (working-tree artifact; summarized here and in the cycle evidence below)

### GREEN (post-fix, real run)

Fix (commit `0c91119f`): `lib/src/simulation/` ships the five certified adapter
families implementing the SAME production interfaces a live binding implements
(`RestContract`, `VendureContract`, `AuthContract`, `AdContract`, and the real
`package:opentelemetry` `SpanExporter`), `SimulationWorld` boots/verifies/binds
them, `NetworkIsolationGuard` (IOOverrides + HttpOverrides) fails every
outbound socket before dialing, `FixtureRegistry`/`SimulationFixtures` automate
fixture commitment + hashing, and `SimulateCommand` is registered on
`CliRunner` (commit `376233bd` records the red tests first).

- command: `dart test test/simulation`
- exit: 0 — `00:07 +41: All tests passed!` (B1–B8: 41 cases, all green)

### Fixture commitment (automated via the real command, commit `852c013d`)

- command: `dart run bin/zfa.dart simulate --scaffold specs/<feature> --family <family>` for the census of affected specs — firebase-auth: 030, 042, 058; vendure: 013, 022, 037, 065; otel: 011, 023, 027 (10 features)
- exit: 0 per feature — `SIMULATED fixtures specs/<feature>/tdd/fixtures families=[<family>] digest=<sha256>`
- determinism: all firebase-auth features share digest `d08179e0d02e0d78aef9a93fd1c43951783b545a6dcf337791919d066b3975d6`, all vendure features `f1925e962093b65ba844b4533b93751028a7a00b79e37d1fc3741f5817820f92`, all otel features `ab948447a85f60b9b62947f6181b48b696ea1aa76f16e53e44883085c0b66ef4`
- each feature's `tdd/cycle-log.md` gains a schema-1 hash-chained entry (`- behavior: <slug>-fixtures`, `- kind: fixtures`, `- prev-hash: genesis`, `- hash: <digest>`, per-file `- fixtures:` sha256 lines)
- replay spot-check: `dart run bin/zfa.dart simulate --feature specs/058-zuraffa-auth-migration --scenario golden` → exit 0, `SIMULATE golden -> GREEN (1/1 plays, guard=active, digest=d08179e0...)`
- TDD-tooling compatibility: `dart run bin/zfa.dart tdd doctor 058-zuraffa-auth-migration` → exit 0, `verdict: healthy`, `drifts: []`

### Verify (mutation audit, real run — see tdd/verification.md)

Three deliberate mutants on the fix's decision surface, each applied, proven
caught, and restored (working tree clean afterwards, `git diff` empty):

- M1 — guard `install()` no-op: `dart test test/simulation/network_isolation_guard_test.dart` → exit 1, `+2 -4: Some tests failed.` (CAUGHT). Restored → exit 0, `+6: All tests passed!`
- M2 — `FirebaseAuthAdapter.signIn` accepts every credential: auth group → exit 1, `+2 -2: Some tests failed.` (CAUGHT). Restored → exit 0, `+4: All tests passed!`
- M3 — `FixtureRegistry.verifyManifest` trusts the manifest blindly: tamper-detection test → exit 1, `+0 -1: Some tests failed.` (CAUGHT). Restored → exit 0, `+1: All tests passed!`
- post-restore re-verification: `dart test test/simulation` → exit 0, `00:07 +41: All tests passed!`

### Refactor

None required beyond the formatter pass (commit `73c71acb`): the adapter
contracts landed in their final shape; `dart format .` + `git diff --stat`
shows zero formatting diffs after it.

### Full suite (fast tier, chunked — tools/run_tests_chunked.sh semantics)

- driver: `bug832_chunks.sh` (foreground batches mirroring the runner's per-chunk command and kernel-cache cleanup)
- result: 70 chunks — **63 PASS / 5 SKIP (no fast-tier tests) / 0 FAIL, 2668 test cases, all passed**; `test/simulation` chunk: `00:08 +41: All tests passed!`
- dart analyze: 0 issues in the changed files; 47 issues on untouched trees (`examples/` etc., present at master — `git diff origin/master --stat -- examples/` is empty)
