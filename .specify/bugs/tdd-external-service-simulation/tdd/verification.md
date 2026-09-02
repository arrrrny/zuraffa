---
feature: tdd-external-service-simulation (bugfix #832, branch mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 73c71acb
behaviors: 8
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # scope: the fix's three load-bearing decisions (guard install, scripted credential enforcement, manifest tamper verification); 3 deliberate mutants, all caught (no mutation tool in profile)
mutants_survived: 0
timing: simulation suite 41 cases ~8s; chunked fast tier across 5 foreground batches (~25 min total); mutants M1/M2/M3 each <15s targeted run + restore + re-verify
suite: fast tier chunked (tools/run_tests_chunked.sh semantics, driver bug832_chunks.sh) — 70 chunks: 63 passed / 5 skipped (no fast-tier tests) / 0 failed, 2668 test cases all passed; test/simulation +41; dart analyze: 0 issues in changed files (47 pre-existing on untouched trees, e.g. examples/, absent from `git diff origin/master --stat -- examples/`); dart format . + `git diff --stat` → zero formatting diffs (style(832) commit also fixes pre-existing drift in migrate_paths_command.dart and gen_namespacing_827_test.dart, red at master HEAD)
---

# TDD Verification: #832 external-service simulation adapters (VISION §9)

**Verdict: PASS_WITH_GAPS.** All four remediation requirements from the
assessment are pinned by real runs: (1) `zfa simulate` exists and drives the
five certified adapter families (B1/B3/B6 — RED proven by the unknown-command
surface at master, GREEN by 41/41 cases); (2) data sources take the adapter
via DI under the SAME production interface (B8 — `container.resolve<RestContract>()`
is the certified adapter, and a generated-style data source runs GREEN through
it with the guard active, which would fail on any real socket); (3) fixture
commitment is automated and hashed into cycle-log evidence (B2/B7 — the
committed worlds for the 10 census-affected specs were produced by the real
command, share per-family digests, and one flipped fixture byte refuses to
boot); (4) the network-isolation guard is sound and free of false positives
(B4/B5 — any `Socket.connect`/`HttpClient` dial throws
`NetworkIsolationViolation` before dialing while file I/O and pure compute
keep working, proven further by 0 new failures across the 2668-case fast
tier). Three deliberate mutants on the fix's decision surface were all caught
and restored. Gaps: this audit was produced by the same session that wrote the
fix and the tests (not independent), mutation was deliberate-mutant sampling
on three decisions rather than a tool run, the Flutter "hosted" profile is
covered by code inspection only (no Flutter SDK in this environment — the
guard hooks `dart:io` overrides which the flutter_tester VM also honors, but
it was not executed here; CI's flutter job covers it), and the rest (Market
Fiyati / Google Shopping) plus AdMob families have no in-tree spec to host
their committed fixtures — their certified worlds ship in
`lib/src/simulation/certified_worlds.dart` and are scaffoldable per feature
(`zfa simulate --scaffold <feature> --family rest|admob`), with the census
gap reported honestly below.

## Root cause (from issue #832 + assessment, confirmed in source)

Specs depending on live externals (auth, Vendure, Market Fiyati, Google
Shopping, AdMob, OtelReporting) could not run GREEN in the TDD loop because
the loop had no VISION §9 simulation worlds: grep confirms `lib/` contained no
`simulate` surface, no adapter families, no `specs/<feature>/tdd/fixtures/`
infrastructure, and no network-isolation guard — every external call would be
real, flaky, and non-deterministic, and nothing could even prove isolation.
The assessment's root-cause hypothesis ("the TDD pipeline was designed without
VISION §9 simulation worlds") is confirmed by absence-of-code evidence in the
RED run rather than by a faulty line to fix: this bug is a capability gap, and
the remediation ships the missing capability minimally.

## The fix

- `lib/src/simulation/simulation_adapters.dart` — the five families, each
  implementing the production interface a live binding implements:
  `FirebaseAuthAdapter implements AuthContract` (scriptable auth states:
  signed-in/out, `user-not-found`/`wrong-password`/`user-disabled`,
  register/`email-already-in-use`, deletion flows incl.
  `requires-recent-login`), `VendureAdapter implements VendureContract`
  (GraphQL golden fixtures keyed by operation name, verbatim replay, recorded
  error surfaces), `RestAdapter implements RestContract` (JSON fixtures
  `"<METHOD> <path>"`, query-string matching, resource-level method fallback,
  scripted faults, deterministic latency), `AdMobAdapter implements
  AdContract` (load/show/dismiss callbacks with scriptable fail codes),
  `OtelAdapter implements the real opentelemetry SpanExporter`
  (capture-and-assert, spans captured through the genuine SDK pipeline).
- `lib/src/simulation/network_isolation_guard.dart` — `IOOverrides.global`
  (`socketConnect`/`socketStartConnect`) + `HttpOverrides.global`
  (`connectionFactory`) throw `NetworkIsolationViolation` BEFORE any dial or
  DNS lookup; file I/O and compute untouched; idempotent install, restorative
  uninstall. Built via `super.createHttpClient` to avoid the override
  recursion that a naive `HttpClient()` inside `createHttpClient` would hit.
- `lib/src/simulation/simulation_world.dart` — golden contract world:
  manifest-verified load (tamper → `FixtureMismatch`), `boot()` installs the
  guard, `bindTo(ZuraffaContainer)` registers the adapters under the
  production contracts, `play()` replays the golden contract deterministically.
- `lib/src/simulation/fixture_registry.dart` — SHA-256 manifest
  (schema-1: per-file sha256 + world digest), tamper verification, and
  hash-chained cycle-log evidence entries reusing the bug #828 chain format.
- `lib/src/commands/simulate_command.dart` (registered in
  `cli_runner.dart`) — `--scaffold` (automated fixture commitment + evidence),
  `--scenario golden|<family>` (machine verdict GREEN/RED + exit code),
  `--verify-guard` (self-certification).

## Proven vs not proven (success criteria from the assessment)

- PROVED — `zfa simulate` per service family: B1/B3/B6 (five families
  scripted, deterministic, guard-active; machine verdict + exit code).
- PROVED — DI with the same production interface: B8 (resolve-identity +
  generated-style data source GREEN through the certified binding).
- PROVED — fixtures committed under `specs/<feature>/tdd/fixtures/` and
  hashed into cycle-log evidence, automated: B2/B7 + 10 committed feature
  worlds with per-family identical digests and schema-1 chain entries; `tdd
  doctor` stays healthy on scaffolded features.
- PROVED — network-isolation guard sound, no false positives: B4/B5 + the
  full fast-tier chunked run (0 new failures in 2668 cases).
- NOT PROVEN HERE — Flutter hosted profile execution (no Flutter SDK);
  rest/admob committed fixtures for in-tree specs (no current spec references
  those families — see census note); independent review of this audit.

## Census honesty note

The issue cites 16 affected specs under issue-time numbering (008–012, 014,
017, 042, 065, 068, 084). The current tree renumbered specs; a grep census
across `specs/` finds the six families in 10 specs (firebase-auth: 030, 042,
058; vendure: 013, 022, 037, 065; otel: 011, 023, 027), each of which now has
its committed fixture world. Market Fiyati / Google Shopping / AdMob have no
in-tree spec; their certified worlds are scaffoldable per feature and ship
with the framework.

## Mutants (deliberate, all caught, all restored)

| Mutant | Injected decision | Evidence | Restored |
|--------|-------------------|----------|----------|
| M1 | `NetworkIsolationGuard.install()` no-op | guard suite exit 1, `+2 -4` | exit 0, `+6` |
| M2 | `FirebaseAuthAdapter.signIn` accepts every credential | auth group exit 1, `+2 -2` | exit 0, `+4` |
| M3 | `FixtureRegistry.verifyManifest` trusts the manifest | tamper test exit 1, `+0 -1` | exit 0, `+1` |

Post-restore: `dart test test/simulation` → exit 0, `+41: All tests passed!`;
`git status --porcelain` empty.
