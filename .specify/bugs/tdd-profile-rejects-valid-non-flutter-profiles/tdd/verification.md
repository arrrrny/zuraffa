---
feature: tdd-profile-rejects-valid-non-flutter-profiles
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: ac4d31c4 (branch fix/680-tdd-profile-rejects-valid-non-flutter-profiles, pre-commit)
behaviors: 5
proven: 2
likely: 1
test_after: 2
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool in profile; deliberate mutant 1/1 caught
mutants_survived: 0
suite: profile writer suite 10/10 (+5 new), full writers dir 31/31, tdd commands + smoke 71/71, test/commands + test/cli 232/232 all green; end-to-end real-CLI: enriched Dart profile accepted (exit 0), nested stacks profile accepted (exit 0), Flutter-target over Dart profile now exits 1 with a named conflict; dart analyze 0 issues
---

# TDD Verification: tdd profile writer accepts valid non-Flutter profiles on re-run (#680)

**Verdict: PASS_WITH_GAPS.** The issue's primary scenario (a valid custom
Dart profile surviving a `zfa tdd init` re-run) is now pinned by regression
tests and re-verified end-to-end — with an important provenance finding: the
master branch had ALREADY absorbed the runner-family guard (commit
`ea399d96`, PR #692, after this assessment was recorded at `6d6064f2`), but
with zero test coverage AND two residual holes: the documented "or vice
versa" cross-family rejection was never implemented (a Dart profile in a
Flutter-targeting init was silently accepted, leaving the baseline invoking
`dart test` against Flutter tests), and the family check was case-sensitive
(`runner: Flutter_test` sneaked through as a "Dart" runner). This change
pins the intended guard with 5 new tests and closes both holes red-first;
a deliberate reverse-guard mutant was caught by exactly the new test.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — a valid custom Dart profile (different `single:`/`runner:`) is accepted as-is when targeting Dart: no StateError, no overwrite, enriched content survives | LIKELY | RED re-derivation on master first: the exact issue repro (fresh_dart_pkg profile enriched to `runner: "package:test (^1.24.0)"` + `single: 'dart test -n "{name}"'`, then `zfa tdd init`) exits 0 with "(already present)" — the guard already shipped unadvertised in `ea399d96`. The behavior was UNTESTED until this change: the new unit test pins acceptance + content preservation; end-to-end re-verified post-change (exit 0). Class is LIKELY not PROVEN because the red predates this session's diff (fix absorbed upstream); this change adds the proof that it stays fixed |
| B2 — a Flutter-runner profile under a Dart-targeting write still throws (flavor conflict preserved) | TEST_AFTER | guard behavior: new unit test asserts StateError; passed before and after (no behavior change intended) |
| B3 — reverse direction: a Dart-runner profile under a FLUTTER-targeting write throws (the documented "or vice versa" contract) | PROVEN | RED first, empirically probed on master BEFORE the fix: probe returned `flutter-writer over dart profile -> null (silently accepted)`. New unit test failed pre-fix (`+8 -2`: `Expected: throws StateError / Actual: emitted null`), passes post-fix. End-to-end on the real CLI: Flutter pubspec + `runner: dart` profile + `zfa tdd init` → exit 1, `tdd_profile_writer: Bad state: … Dart runner ("dart") but zfa tdd init is targeting a Flutter project` |
| B4 — the family check is case-insensitive: `runner: Flutter_test` under a Dart-targeting write is a flavor conflict, not a valid Dart runner | PROVEN | RED first: probe returned `dart-writer over "runner: Flutter_test" -> null (accepted)`. New unit test failed pre-fix, passes post-fix (`_runnerFamily()` normalizes case) |
| B5 — an existing profile with NO parseable runner still falls back to the exact-content guard (untrusted flavor → reject; `--force` overwrites) | TEST_AFTER | pins the pre-existing empty-runner semantics so the new family logic cannot accidentally widen acceptance: no-runner + differing content → StateError; `force: true` → overwrite. Passed before and after |

No pre-existing test was weakened: the 5 original writer tests (write,
idempotent no-op, refuse-clobber, force-overwrite, force-noop) run
byte-for-byte unchanged and green; `refuses to clobber` remains correct
because its fixture has no parseable runner (exact-content fallback). No
assertion loosened, no test skipped or renamed, no threshold lowered.

## Deliberate mutants (no mutation tool in the profile; sampling on the changed guard)

| # | Mutant (one small change, restored exactly after) | Result |
| --- | --- | --- |
| 1 | Reverse-direction guard disabled: `&& false` injected into the `runnerFamily == dart && writingFamily == flutter` condition | CAUGHT — the new B3 test fails: `Expected: throws StateError / Actual: emitted null` (+0 -1). Restored exactly; writers dir re-run green (+31, 0 failures) |

Restored exactly after the mutant. Sampling covers the NEW branch (B3 — the
only changed decision); B1's acceptance branch and the case-normalization
were not mutated separately: B1 was already pinned by the failing-then-passing
pre-fix cycle recorded in the probe, and B4's test failed for the same
normalization line before the fix.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Provenance (not a defect of this change): the runner-family guard this assessment prescribes was already merged to master inside `ea399d96` (PR #692) AFTER the assessment was recorded (`6d6064f2`), unadvertised and untested. The assessment's line numbers (`tdd_profile_writer.dart:23-63` exact-content guard) describe the pre-`ea399d96` file and no longer match master. This change therefore (a) adds the missing regression coverage for the prescribed behavior and (b) closes the two holes the partial fix left open | `git log -1 --all -- .specify/bugs/tdd-profile-rejects-valid-non-flutter-profiles/`; `git diff 1f8d4099 ea399d96 -- lib/src/cli/writers/tdd/tdd_profile_writer.dart` |
| 2 | LOW | The vice-versa rejection (B3) changes observable behavior for `zfa setup`/Flutter-targeting inits that previously (post-`ea399d96`) silently kept a Dart profile. That silent keep is the bug (wrong runner for the project); the new StateError names the conflict and the remedy ("Delete the file first to re-detect"), matching the documented contract | probe output; e2e exit-1 message; doc comment `write()` layer 4 |
| 3 | LOW | Same-session audit (Hard Rule 2): tests and fix were written in this session, so the smell pass is not independent. Mitigation: new tests follow the file's established style (tmp dir, `seedProfile` helper mirrors the original fixture style) and the mutant pass was executed blind before results were recorded | session transcript |

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) |
| --- | --- | --- |
| "For non-Flutter projects, TddProfileWriter should accept any existing tdd-profile.md that uses a Dart runner — different metadata should not trigger a rejection" (issue Expected Behavior) | B1 | `tdd_profile_writer_test.dart` group "issue #680 — runner-family guard" acceptance case; e2e `zfa tdd init` exit 0 on enriched + nested-stacks profiles |
| "If existing runner is Flutter AND writing Dart → throw (flavor conflict)" (assessment remediation step 2) | B2 | flavor-conflict unit test |
| "If existing runner is non-Flutter → return null" (assessment remediation step 3) | B1 | acceptance unit test (null + content preserved) |
| "If both Flutter → fall back to exact-content match" (assessment remediation step 4) | B5 (and original refuse-clobber/force tests, unchanged) | exact-content fallback unit tests |
| Documented contract "cross-family … or vice versa is rejected" (writer doc comment, layer 4) | B3 | reverse-direction unit test + e2e exit 1 |

All three issue/assessment criteria are covered; the two extra behaviors
(B3, B4) close holes in the same guard the issue targets.

## What was not audited

- Downstream consumers of the profile beyond `SingleTestRunner` were not
  re-audited for the vice-versa behavior change; the search for
  `TddProfileWriter` callers found `init_command.dart`, `setup_command.dart`
  and the writer's own tests only.
- The YAML frontmatter parser remains regex-based (`_extractRunner`): shapes
  beyond `runner:` on any line (e.g. block scalars `runner: |`, JSON-style
  profiles) are still unparsed and intentionally fall to the exact-content
  guard (B5). A real YAML parse was out of scope for this mechanical fix.
- The rest of the fast suite beyond the suites listed in `suite:` was not
  re-run per-bug; the shared chunked run is recorded once for the combo.
