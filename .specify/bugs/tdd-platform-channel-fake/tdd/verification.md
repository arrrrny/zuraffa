feature: tdd-platform-channel-fake
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix/831-tdd-platform-channel-harness (base bd535c07)
behaviors: 15
proven: 0
likely: 12
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: n/a # no mutation tool in this environment; no deliberate mutants run
mutants_survived: 0
suite: fast tier 67/67 directory chunks passed / 0 failed (resumable driver mirroring tools/run_tests_chunked.sh, chunked per directory, kernel caches cleared); 831 feature suites 82 passed / 0 failed across five files (fake-command 7 incl. analyzer parse pin, gen-platform 4 incl. emitted-Dart parse pins, scenario schema 11, classifier 39 incl. the 8 new issue-831 pins + the extended taxonomy pin, reader 22 incl. the 3 new platform pins); dart analyze 47 issues = master baseline (0 on touched files); dart format clean on all 17 touched files
---

# TDD Verification: `zfa tdd fake` — platform-channel certified fakes, scenario-committed intent, and the platform harness (#831)

**Verdict: PASS_WITH_GAPS.** The bug is fixed test-first: the RED run (12
failures / 0 passes across the five suites, evidence quoted in
`cycle-log.md`) failed for exactly the bug's reasons — `zfa tdd fake` did not
exist, the scenario model was missing (`Could not find
'package:zuraffa/src/plugins/tdd/models/channel_scenario.dart'`),
`BehaviorKind.platform` and `RedClassification.channelTimeout` did not exist,
and a platform row in a test list was rejected as
"table row outside an outer/inner loop behavior section". After the fix all
82 feature-suite tests pass and the full fast tier (67 chunks) passes with
zero failures. Gaps: test + fix land in one commit (repo convention), so git
ordering alone proves only `LIKELY` for the 12 red-first behaviors; mutation
strength is unmeasured (no mutation tool in this environment); and 3 guard
pins re-assert pre-existing master behavior inside the new classifier group
(bare-timeout → runner-error, SIGKILL precedence, green-run unaffected) —
classified NOT_APPLICABLE (guard) because those behaviors were already pinned
green on master (U9/U10) before this change.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B-001 — `fake` writes the committed-intent scenario + certified fake, behavior-bound by `--behavior` | LIKELY | red: no `fake` subcommand; green: exact paths pinned (`specs/<f>/tdd/scenarios/t1.json`, `test/tdd/<f>/fakes/t1_fake.dart`) |
| B-002 — the fake registers via `TestDefaultBinaryMessengerBinding`, replays the scenario, records observed calls; emitted Dart parses | LIKELY | red: command absent; green: content pins + `parseString` yields zero errors |
| B-003 — a re-run keeps the committed scenario and regenerates the fake; `--force` rewrites | LIKELY | red: command absent; green: edited intent survives a re-run byte-for-byte; `--force` reproduces the deterministic starter |
| B-004 — unknown platform token refused before any write; missing `--feature` is a usage error | LIKELY | red: command absent; green: refusal precedes the write (no scenario file exists after the failed call) |
| B-005 — the machine summary names channel/feature/behavior/slug/scenario/fake/platforms | LIKELY | red: command absent; green: every `key=value` pinned on the final line |
| B-006 — scenario schema law (value XOR error, loud required default, closed platform set) | LIKELY | red: model file missing (suite failed to load); green: 11 schema pins incl. every rejection |
| B-007 — scenario round-trips; permission states are plain values | LIKELY | red: model file missing; green: round-trip + granted/denied as values |
| B-008 — `## Platform harness` header + `platform` cell resolve to the platform kind | LIKELY | red: `Member not found: 'platform'` (load error); green: both dialects resolve, orphan rows still reject |
| B-009 — gen refuses a platform row without a committed scenario, naming the fake command | LIKELY | red: gen rejected the row itself ("outside a behavior section"); green: honest refusal with the remedy + zero files written |
| B-010 — gen emits the platform-harness pair (fake install, recorded-calls assertions, loud unscripted) + channel subject stub | LIKELY | red: plain-pair path / row rejection; green: content pins + emitted Dart parses cleanly |
| B-011 — gen keeps the registry + JSON-verdict contract (`kind=platform`) | LIKELY | red: row rejection before any registry write; green: registry + compact verdict pinned |
| B-012 — MissingPluginException / channel-scoped TimeoutException / PlatformException(channel-error) → channel-timeout with a remediation hint | LIKELY | red: `Member not found: 'channelTimeout'` (load error); green: three transcript fixtures classify channel-timeout |
| B-013 — an assertion signature beats channel text (assertion stays king) | LIKELY | red: load error; green: Expected/Actual block quoting channel text still classifies assertion |
| B-014 — bare TimeoutException stays runner-error; SIGKILL stays runner-error; green runs unaffected | NOT_APPLICABLE (guard) | pins master behavior already green under U9/U10; re-asserted inside the new group so precedence stays pinned as the taxonomy grows |
| B-015 — `--platforms` records the hosted matrix in the committed scenario; the harness is platform-agnostic Dart | LIKELY | red: command absent; green: decoded scenario `platforms` pinned, summary carries the matrix, no platform-specific code emitted |

## Weakened-existing-test audit

No pre-existing test was weakened: no assertion removed, loosened, skipped, or
filtered; no threshold lowered. Two pre-existing files were EXTENDED (reader
platform group, classifier issue-#831 group) and two pins UPDATED where the
issue legitimately grows the taxonomy: the classifier's label-list pin now
names seven classes (was six — channel-timeout is the seventh, the issue's
requirement 4), and its `record()` helper gained a defaulted `timedOut` flag
(every existing call site unchanged). The staleness/adopt contracts
(`generated_shape.dart`) are untouched; both platform writers emit the
standard provenance headers so `--adopt` and the bug-#683 staleness re-render
apply unchanged. The pre-existing failure in
`commands/gen_command_theme_test.dart` (stale flat-path expectation vs the
#827 feature-namespaced layout, failing at master `bd535c07` before any 831
change) was deliberately left untouched — repairing #841's test is outside
this issue's scope and the failure is identical before and after this branch.

## Smell pass

- No test asserts on a double it configured: the fake replays a COMMITTED
  scenario file, and the harness asserts the replay equals the scenario (the
  intent), never the fake's own construction.
- No vacuous `expect(true, isFalse)` placeholders; the honest-red proof
  asserts the stub error is GONE after implementation (`expect(result, isNull,
  reason: ...)` — assertion-level failure on the stub, per the #830/#841
  assertion-first house pattern).
- Parse-level guards (analyzer `parseString`, zero errors) pin the generated
  template escaping — the failure mode generated code actually has.
- Determinism: no wall-clock sleeps; the harness drives the fake's messenger
  synchronously through awaited futures; temp fixtures are
  `Directory.systemTemp` with teardown.
- Refactor sensitivity is LOW by construction: assertions target the emitted
  contract surface (class name, scenario path, recorded-call fields), not
  private internals.

## Criteria coverage (issue requirements → evidence)

| # | Requirement | Covered by |
| - | ----------- | ---------- |
| 1 | `zfa tdd fake <channel>` generates a framework-certified fake (TestDefaultBinaryMessengerBinding handler replaying a scenario script) | B-001, B-002, B-003 |
| 2 | `zfa tdd gen` for platform-backed behaviors installs the fake and asserts on observed calls (arguments recorded, ordering) | B-009, B-010, B-011 |
| 3 | Scenario scripts live in `specs/<feature>/tdd/scenarios/*.json`, committed as intent (not agent-written mocks) | B-001, B-003, B-006, B-007 |
| 4 | verify-red classification for channel-timeouts vs assertion failures | B-012, B-013, B-014 |
| 5 | Cross-platform matrices: same scenario runs on ios/android/macos where feasible | B-015 (scenario-declared matrix on a closed token set; platform-agnostic emitted harness; hosted execution stays a TddProfile concern — the honest `where feasible` boundary) |
