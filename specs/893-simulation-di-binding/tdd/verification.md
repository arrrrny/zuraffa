---
feature: 893-simulation-di-binding
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 63a065fc
behaviors: 20
proven: 20
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 19
criteria_covered: 19
mutation_score: null # no mutation tool in profile; deliberate-mutant sampling only
mutants_survived: 0 # 3/3 sampled mutants caught, each restored + suite re-verified green
suite: fast tier chunked 67/67 chunks, 0 failures; scoped simulation+di+mock 125 passed, 0 failed
---

# TDD Verification: Simulation-Mode DI Binding (spec 893)

**Verdict: PASS_WITH_GAPS.** Discipline holds: every behavior has a recorded
red before its green, git history shows each test landing in the same commit as
its source with the cycle-log carrying the red command and output, the full
fast-tier suite is green (67/67 chunks, zero failures), all three sampled
deliberate mutants were caught, and no HIGH smell was found — but the evidence
is weak in four specific places listed below, and the smell pass (fresh
subagent, rubric-graded) returned 10 MED + 5 LOW findings that are remediation
work, not blockers.

**Independence disclosure (Hard Rule 2):** this audit was produced by the same
session that wrote the tests. The files were re-read in full, the smell pass
was delegated to a fresh-context subagent and its citations were vetted line by
line, but the audit is not independent. Weight it accordingly.

## Test-first evidence

The repo profile's convention is "red test committed alongside the
implementation in the same commit, cycle log records the red command + output"
(`.specify/memory/tdd-profile.md`). Under the rubric that shape is `PROVEN`
when the cycle log holds the red command and its failure output and history
corroborates the pairing. All six cycles qualify; cycle-log entries are
schema-1 hash-chained (genesis → a56e… → 4a2c… → face… → fc0e… → 3573… → 269f…
→ eede… → 8597… → 4336… → 666d… → 0b23…).

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| A1, U1, U2 (flavor detection, FR-012 gate) | PROVEN | cycle-log red `a56e3f54` (exit 1, undefined names) → green `4a2c3057`; commit 77a3e749 pairs test + source |
| A2, U3, U4, U6 (generated bindings + index wiring) | PROVEN | cycle-log red `face1906` (0/7) → green `fc0e9bec`; commit f8c8f953 |
| A3, U5 (distinguishability, real-adapter guard) | PROVEN | same cycles; assertions verified in-tree |
| U14 (committed fixtures through #832 registry) | PROVEN | cycle-log red `35734bb1` (0/2) → green `269f983d`; commit ff2a91d8 |
| A4, U7, U8, U9, U10 (whitelist lanes + config) | PROVEN | cycle-log red `eede70ad` → green `85979604`; commit c35c7640 |
| A6, U11, U12, U13 (boot, FR-009/FR-010, demo graph) | PROVEN | cycle-log red `43363658` → green `666d5c9b`; commit b9632413 |
| T006 refactor (format/analyze/chunked) | PROVEN | cycle-log `0b237457`; commits 21f52922, 63a065fc |

Weakened-existing-test check: `git diff master..HEAD -- test/` modifies five
pre-existing test files under `test/plugins/tdd/` — every hunk is a
`dart format .` line-wrapping reflow; zero assertions removed, loosened, or
renamed. No existing test was weakened.

## Findings

Ordered by severity. HIGH: none. The full MED/LOW catalogue (fresh-context
pass, citations vetted) with the highest-impact items:

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | Generated simulation DI is verified by text presence only, never compiled or executed — a generator mutant emitting non-compiling Dart passes | test/plugins/di/simulation_binding_test.dart:140,151-158,166-170,201-204,227-232 |
| 2 | MED | Whitelisted-lane proof depends on real DNS for `analytics.example.com`; wildcard-resolving networks flip the test and open a real socket | test/simulation/network_isolation_guard_whitelist_test.dart:89-92 |
| 3 | MED | Eager test U8 exercises four behaviors in one body | test/simulation/network_isolation_guard_whitelist_test.dart:71-111 |
| 4 | MED | Comment claims whitelisted HttpClient path is permitted, but only the blocked branch is asserted — the `connectionFactory` delegation has no test | test/simulation/network_isolation_guard_whitelist_test.dart:102-109 |
| 5 | MED | FR-008 no-op does not assert `report.fixtures` is empty or the specific skip warning — a mutant that still loads fixtures outside the flavor survives | test/simulation/simulation_boot_test.dart:249-264 |
| 6 | MED | Corrupt-fixture test does not pin FR-009's entity-naming contract (sibling missing-file test does) | test/simulation/simulation_boot_test.dart:123-133 |
| 7 | MED | A6 demo graph is a hand-mirrored double of the generated shape, not sourced from a generation run | test/simulation/simulation_boot_test.dart:19-63,170-192 |
| 8 | MED | Eager tests: A2 (three workflows) and U14 (five concerns) | test/plugins/di/simulation_binding_test.dart:82-126; test/plugins/mock/simulation_fixture_writer_test.dart:47-106 |
| 9 | MED | Duplicate expensive `dart run` probe — two identical subprocess compilations where one suffices | test/simulation/simulation_flavor_test.dart:33-37,39-43 |
| 10 | LOW | Fixture record values pinned by key existence only; duplicated entity/fixture seeding across files; CWD-dependent probe path; bare-await assertion; A6 name misleads | simulation_fixture_writer_test.dart:81-85,95; simulation_flavor_test.dart:93-96; simulation_boot_test.dart:147-148 |

## Mutation results

No mutation tool in the profile (`.specify/memory/tdd-profile.md`); deliberate
mutants on the highest-risk behaviors. Sample: 3 of 20 behaviors — flavor
routing (US2), guard lane enforcement (US3), fixture fail-fast (FR-009). Each
mutant was one small change, run against its behavior's test, restored exactly
(`git checkout --`), and the suite re-run green afterward.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `simulation_binding_builder.dart:79` flavor guard inverted (`!kSimulationMode` → `kSimulationMode`) | U3 | No | Caught by the U3 text assertion — though see finding 1: the catch is textual, not behavioral |
| `network_isolation_guard.dart` `_isAllowed` short-circuited to `return false` | U8 | No | Whitelisted connect blocked with violation instead of `SocketException` — delegation contract pinned |
| `entity_fixture.dart` missing-fixture branch returns `[]` instead of throwing | U11 | No | `SimulationFixtureError` with entity name expected, none thrown |

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| FR-001 / SC-004 | A1, U1 | Yes (real toolchain define via subprocess probe) |
| FR-002 / SC-003 / FR-013 | A2, U3, U4, U6 | Yes (real generator entry points: DiPlugin + MockPlugin, the same units the CLI commands drive) |
| FR-003 / SC-006 / FR-011 | A2, A3, U3, U5, U14 | Yes |
| FR-004 / SC-001 | A6 | Yes (mock-only graph through DI; the 2-second boot threshold is NOT measured — gap) |
| FR-005 / SC-002 | A4, U9, A6 socket-block | Yes (real IOOverrides/HttpOverrides interception) |
| FR-006 | U7, U8, U10 | Yes |
| FR-007 | A4 | Partial: block + violation type asserted; the diagnostic message content naming the source is not explicitly asserted |
| FR-008 | boot no-op test + existing #832 uninstall/restore suite | Yes |
| FR-009 / SC-005 | U11, A6 | Yes |
| FR-010 | U13 | Yes |
| FR-012 | A5, U4 | Yes |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- `flutter run --dart-define=SIMULATION=true` against a real generated Flutter
  app: not executable on this agent (no Flutter SDK, headless). The
  demoability proof (A6) runs the runtime boot + a generated-style mock graph
  through the real DI container under the real guard, and the define routing
  is proven through the real toolchain via a subprocess — but a full Flutter
  app boot is unproven here.
- SC-001's 2-second boot threshold: not measured, no timing assertion exists.
- Mutation: deliberate-mutant sampling only (3 of 20 behaviors); not
  exhaustive. Coverage: not run (opt-in per profile).
- Generated DI/index files are asserted textually (finding 1); no compile or
  execution of emitted Dart.
- The slow tier (`--preset=all`, regression/integration/property/benchmark)
  was deliberately not run per the repo's own disk-safety rules for ~10 GB
  cloud agents.
- `plan.md`/`tasks.md` were not present in the committed spec; they were
  derived from `spec.md` + the approved T001–T006 table during this run and
  are disclosed as such in both files.
- The cycle-log hash chain uses the schema-1 format the repo's tooling parses;
  the hash payload formula is this feature's declared convention
  (`sha256(prev+behavior+kind+command+exit+output)`) and has not been
  cross-validated against the doctor's chain validator.
