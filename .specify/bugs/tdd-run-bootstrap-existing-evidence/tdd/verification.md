---
bug: 682-tdd-run-bootstrap-existing-evidence
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: session 2026-09-01 (branch fix/682-tdd-run-bootstrap-existing-evidence, base 387f1f29, pre-commit)
behaviors: 4
proven: 4
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: unmeasured # quick-class audit — 2 deliberate mutants run and caught instead
suite: fast 2494 passed, 0 failed (chunked, 60 chunks, exit 0) / targeted slow: run_command 24/24 (3 new), sc_014 5/5, scenarios 64/66, make_command 21/23, verify_red+refactor+runner+smoke 48/48
---

# TDD Verification: bug #682 — `zfa tdd run` bootstraps run-state from existing evidence

**Verdict: PASS_WITH_GAPS.** Every behavior in the fix carries recorded
red-then-green evidence from real CLI-driven runs in this session, all four
criteria from the refined assessment reach a test, the full fast suite
(2494 tests, chunked, disk-safe runner) passes with zero failures, and every
remaining targeted-suite failure is proven pre-existing on the pristine tree
(stash run). The gaps that keep this from `PASS`: mutation strength was not
measured by the harness (quick-class audit; two deliberate mutants were run
and caught instead), and the audit was produced by the same session that
wrote the fix (see "Audit independence disclosure").

## Audit independence disclosure

The same session authored the fix, the tests, and this audit. Mitigations
applied: both RED runs were executed and their output captured verbatim
before any source change landed; every GREEN number below comes from a real
`dart test` process in this session, not from memory; two deliberate mutants
(Hard Rule 4 procedure) were applied to the new reconcile logic, observed to
fail the locked tests, restored exactly, and the suite re-run green; the
pre-existing failures claimed below were reproduced on the stashed pristine
tree before being marked unrelated.

## Test-first evidence

The RED phase ran BEFORE any source change: the two new driver tests were
executed against the unmodified tree (base 387f1f29) and failed for the RIGHT
reason — the runner re-drove already-certified behaviors, which is the issue's
symptom at the driver level. The GREEN phase then applied the fix and re-ran
the same suites.

| Behavior (assessment remediation) | RED evidence (verbatim failure mode) | GREEN evidence |
| --- | --- | --- |
| B1 — fresh bootstrap (no `run-state.json`): evidence-backed states promoted, run completes | `Which: at location [0] is 'gen B-001' instead of 'make B-003'` — B-001 (red+green certified) re-driven from gen; 16 invocations instead of 6; no `1 already done — skipping` line | bug-682 fresh-bootstrap test passes: exact 6-invocation list (`make B-002`, `refactor B-002`, full cycle for B-003), `1 already done — skipping`, state file `{done, done, done}`, exit 0 |
| B2 — all-pending `run-state.json` + complete evidence: nothing re-driven | `Expected: empty / Actual: ['gen B-001', 'verify-red B-001', … 'refactor B-003']` — the issue's exact repro state re-drove the whole 12-step cycle | bug-682 all-pending test passes: `stepInvocations` empty, `3 already done — skipping`, `result=complete pending=0 red=0 green=0 done=3`, exit 0, state file all `done` |
| B3 — green-only evidence promotes to GREEN; owed refactor honestly misfires while red evidence missing | Not independently red (composed with the pre-existing misfire contract); the promotion half is covered by B1's red and the misfire half is a pin on existing FR-003/FR-011 behavior | bug-682 green-only test passes: exact 7-invocation list, verbatim `refactor certified but evidence for "B-001" is incomplete in tdd/cycle-log.md (red: false, green: true)`, `result=runner-error … stopped_at=B-001:refactor`, exit 2, B-001 stays `green` |
| B4 — an in-flight marker keeps resume semantics (no bootstrap promotion in a marked file) | Surfaced as an observed regression of the first fix iteration (per-row exemption): U23 case 2 failed `Bad state: No element` and sc_014 A5 case 2 failed `has length of <3>` — promotion leaked into interrupted-run files | Gate finalized (`bootstrappable = state.inFlightBehaviorId == null`) with ZERO existing-test edits: U23 passes, sc_014 5/5 including both A5 cases |

## Existing-test audit (Phase 2)

The delivered diff touches exactly two source files
(`lib/src/plugins/tdd/commands/run_command.dart`, +25/−7;
`test/plugins/tdd/run_command_test.dart`, +114/−0) and adds three tests; no
existing assertion was removed, loosened, renamed, skipped, or re-filtered,
and no coverage/mutation gate was touched (`git diff` reviewed line by line).
One honesty note: the first fix iteration (per-row in-flight exemption) did
break U23 and sc_014 A5; that iteration was discarded in favor of the
file-level gate, and the delivered fix passes every pre-existing test
unchanged.

## Suite evidence (real runs, this session)

- `dart analyze` — No issues found (whole repo, post-fix).
- `tools/run_tests_chunked.sh` (fast suite, disk-safe) — exit 0, 60/60
  chunks green, **2494 passed / 0 failed**.
- Targeted slow suites (real `dart test --preset=all --tags=slow` runs):
  - `test/plugins/tdd/run_command_test.dart` — **24 passed / 0 failed**
    (21 pre-existing + the three bug-682 tests).
  - `test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart` — **5 passed /
    0 failed** (kill-mid-step resume contracts unchanged).
  - `test/plugins/tdd/scenarios/` (all) — **64 passed / 2 failed**; the two
    failures (sc_018 plan→run e2e, sc_021 acceptance-composition e2e) are
    heavyweight real-pipeline tests that time out in this sandbox and were
    reproduced on the stashed pristine tree — pre-existing, unrelated to the
    fix.
  - `test/plugins/tdd/make_command_test.dart` — **21 passed / 2 failed**;
    both failures (the bug-657 make-hint test and A11/U17) reproduce on the
    stashed pristine tree — pre-existing fallout of the #699 composition
    gate suppressing the 657 hint when no test list exists, out of scope
    here.
  - `verify_red_command_test.dart` + `refactor_command_test.dart` +
    `runner_test.dart` + `tdd_command_smoke_test.dart` — **48 passed /
    0 failed** (combined run with make_command: 71 ran, the only 2 failures
    were make_command's).
- `dart format --output=none --set-exit-if-changed` on the two delivered
  files — 0 changed. (Full-repo `dart format .` under the local Dart
  3.13.3 flags tall-style drift in two committed files the fix never
  touched; those were restored and are not part of the delivered diff.)
- Disk housekeeping: kernel caches cleared by the chunked runner between
  chunks; stash/mutant artifacts restored; `df -h .` shows 7.9G free
  (16% used) at verification time.

## Deliberate mutants (Phase 4, quick-class)

No mutation harness run (the profile's mutation scope targets spec
suites, and a full mutation run would fill this sandbox's disk). Two
hand-written mutants on the new reconcile logic, one at a time, each
restored exactly and the suite re-run green afterwards:

1. Gate removed (`(bootstrappable && claimed == pending)` →
   `claimed == pending`): **caught** by U23 — `Bad state: No element`
   (the marked pending behavior was promoted and skipped, so the
   in-flight re-entry assertion found an empty invocation list).
2. Promotion mapping corrupted (`hasGreen` → `done` instead of `green`):
   **caught** by the bug-682 green-only test — invocation list mismatch at
   location [6] (`refactor B-001` never ran because B-001 was wrongly
   done).

Restoration was verified by `git diff --stat` (authored +25/−7 shape),
`dart format --set-exit-if-changed` clean, and a full re-run of
run_command_test.dart (24/24) and sc_014 (5/5) after restoration.

## Criteria coverage (from assessment.md remediation)

1. **Bootstrap with no `run-state.json`** — mixed evidence promotes
   (red+green → skipped/done, red → re-enters at make, none → full cycle),
   run completes exit 0, promoted states persisted (PROVEN: bug-682
   fresh-bootstrap test through the real CliRunner surface).
2. **All-`pending` state file + full evidence** — zero step invocations,
   everything promoted to `done`, completion summary exact (PROVEN:
   bug-682 all-pending test).
3. **No evidence stays pending; greenfield runs unchanged** — U19 (full
   cycle for evidence-less behaviors) passes unchanged, and B1/B2's B-003
   rows pin the none → `pending` mapping (PROVEN).
4. **Interrupted-run resume dominance** — the marker gate keeps U23 and
   sc_014 A5 resume contracts byte-for-byte (PROVEN: both suites green on
   the delivered fix; mutants 1 demonstrates the tests actually police
   it).

## What was not audited

- Mutation strength via the harness: not run (quick-class audit; two
  deliberate mutants only, listed above).
- The real-CLI end-to-end path (`zfa tdd run` against a live `zfa` binary
  in a fresh pub-get project): sc_018/sc_021-style real-pipeline coverage
  for the bootstrap was not executed here — those e2e scenarios time out in
  this sandbox for pre-existing reasons (proven on the pristine tree), and
  no new real-pipeline scenario was authored for the bootstrap.
- The reporter's own brownfield package (`zuraffa_permissions`) was not
  available; the brownfield shape is covered by the fixture-based tests
  (seeded cycle logs, seeded/absent state files) rather than the actual
  artifact from the issue.
- Mutation of the demotion path and the two-phase driving loops: covered by
  pre-existing suites but not re-mutated in this audit.
