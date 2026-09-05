---
feature: issue-1024-fleet-rot-compile-gate-xray-deck-delete-di-command
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 77e69f24
behaviors: 5
proven: 4
likely: 1
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 4/4 sampled mutants killed (100% of sample; fallback audit, no .zfa.json → LLM-guided verify)
mutants_survived: 0
suite: fast tier chunked runner 74/74 chunks passed / 0 failed; dart analyze 345 issues == pre-change baseline (0 in lib/test); dart format 0 changed
---

# TDD Verification: compile-gate xray deck + delete dead di_command.dart (#1024)

**Verdict: PASS_WITH_GAPS.** All three issue exit criteria are met with
automated or documented evidence, and the class of bug (an emitter whose
output does not compile, pinned green by string-match assertions) is now
structurally prevented: the compile gate runs `dart analyze` on the generated
deck inside a pure-Dart sandbox package on every test run, and every deck
generation writes a `proof.v1` receipt digesting the emitted bytes. Gap: the
in-session red→green ordering is recorded in `tdd/red-evidence.txt` /
`green-evidence.txt`, but tests and fix land in one commit, so git history
alone cannot independently prove test-first ordering (graded `LIKELY`, same
standard as #609's PASS_WITH_GAPS). This audit used the spec-kit TDD
extension's fallback path: `.zfa.json` is absent at the repo root, so
`zfa tdd verify` was not dispatchable; mutation strength was instead sampled
with 4 deliberate mutants (all killed).

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — deck calls `XRayControlDeck.instance.registerEntries` with resolving imports (pure-Dart guard, no flutter import) | PROVEN | compile-gate test (`xray_deck_cli_test.dart`) asserts exit-0 `dart analyze` in a sandbox; pins assert the real API + absence of `XRayControlDeckRegistry`/`foundation.dart`; red evidence shows 7 analyze errors pre-fix |
| B2 — YAML `description` preserved compile-safely (doc comment, not a named arg) | PROVEN | pins assert `/// Triggers validation failure` and `isNot(contains('description:'))`; gate proves compilation; mutant M3 killed |
| B3 — unrecognized `type:` maps to `XRayMockType.unknown` (output stays compilable) | PROVEN | gate YAML carries `type: nonsense`; pins assert `XRayMockType.unknown`; mutant M2 killed |
| B4 — proof receipt per deck generation (proof.v1, sha256-bound) | PROVEN | gate test asserts `.zfa/receipts/` document with schema/command/target/api; mutant M5 killed; green evidence shows the full receipt JSON |
| B5 — `di_command.dart` deleted; `zfa di create Foo` unaffected; zero `DiCommand` refs | LIKELY | deletion is the diff itself (structurally guaranteed); sandbox runs of `zfa di create Foo` (`--no-entity` and entity-based) succeeded post-deletion (`green-evidence.txt` Step 5); the routing (`DiPlugin`→`ModularDiCommand`) is exercised by the existing fast-tier DI tests in the chunked suite |

No pre-existing test was weakened: the only modified test
(`xray_deck_cli_test.dart`) had two assertions that pinned the BROKEN output
replaced by strictly stronger evidence (compile gate + receipt pins); all
other assertions were preserved.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The compile gate shells `dart pub get --offline` + `dart analyze` (~5–15 s JIT per run); acceptable for the fast tier it lives in, but it couples the test to a warm pub cache and a Dart SDK on PATH (both guaranteed in CI after `dart pub get`) | `test/commands/xray_deck_cli_test.dart` gate test |
| 2 | LOW | `_safeMockType` prints a warning but cannot be asserted from the gate test's captured output without another string pin; the emitted `XRayMockType.unknown` is what is pinned instead | `xray_deck_command.dart` |
| 3 | LOW | B5's absence check (file does not exist) is enforced by the PR diff rather than a runtime test; a future re-add would not fail CI on its own | assessment.md remediation plan |

## Exit criteria (issue #1024)

| Criterion | Status | Evidence |
| --------- | ------ | -------- |
| `zfa xray deck` output passes `dart analyze` in temp sandbox | MET | gate test green; `green-evidence.txt` Step 3 (`No issues found!`) |
| `lib/src/commands/di_command.dart` does not exist | MET | `git rm` staged deletion; `green-evidence.txt` Step 5 (`ABSENT ✓`) |
| `zfa di create Foo` succeeds (unchanged) | MET | sandbox runs, both modes (`green-evidence.txt`); chunked suite DI chunks green |

## Mutation sampling

| Mutant | Change | Result |
| ------ | ------ | ------ |
| M1 | emit `XRayControlDeckRegistry.registerEntries` (original bug) | KILLED (API pin + gate) |
| M2 | drop `_safeMockType` sanitize | KILLED (`XRayMockType.unknown` pin) |
| M3 | drop description doc-comment | KILLED (`///` pin) |
| M5 | `_emitDeckReceipt` no-op | KILLED (receipt pins) |

M4 class (dead import path) is covered by M1 + the gate (an import that does
not resolve fails `dart analyze` regardless of the call site). Working tree
verified byte-identical after every mutant (`tdd/mutation-evidence.txt`).

## Verification environment

- Dart SDK 3.13.3 (stable), Linux x64; branch
  `fix/1024-xray-deck-compile-gate-delete-di-command` @ `77e69f24` + this fix.
- Full log chain: `tdd/red-evidence.txt`, `tdd/green-evidence.txt`,
  `tdd/cycle-log.md`, `tdd/mutation-evidence.txt`.
