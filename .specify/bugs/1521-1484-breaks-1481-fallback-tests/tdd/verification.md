---
feature: 1521-1484-breaks-1481-fallback-tests (bug #1521)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working-tree of 58ad4eed (branch fix/1521-1484-breaks-1481-fallback-tests, based on feat/1484-fr-manual-exemption)
toolchain: Dart 3.13.3 stable (no Flutter SDK in this sandbox)
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
suite: plan_command_bug_1481_test.dart 8 passed, 0 failed (red-first: +5 -3 pre-fix); chunked suite (CI parity --exclude-tags flutter) green across all top-level chunks; dart analyze clean on changed files; dart format 0 changed repo-wide
---

# TDD Verification: #1481 fatal unit-fallback expectations updated to feature 1484's manual routing (issue #1521)

**Verdict: PASS_WITH_GAPS.** All three stranded behaviors from
`assessment.md` are `PROVEN` with red-first evidence against the real
`zfa tdd plan` code path. The gap is environmental, not evidential:
this sandbox has no Flutter SDK, so the Flutter-tagged slices of the
suite are excluded exactly as CI excludes them (`--exclude-tags
flutter`), and one pre-existing failure in a NEIGHBOR suite
(`bug_1432_platform_lane_rows_test.dart`, +1 -3) was proven unrelated
by re-running it with this fix's diff stashed — it fails identically
on pristine HEAD `58ad4eed`. No stale or copied evidence — every run
below is from this session.

## Proven behaviors (this session's runs)

| id | behavior | class | evidence |
| -- | -------- | ----- | -------- |
| T-U1 | unbound FR routes to a manual declaration (warning + destination + both remedies rendered; no unit route line; no fatal fallback class) while the scenario heals to declared in the same invocation | PROVEN | red: `00:00 +5 -3` with `route: U1 -> unit lane [fallback: no declared trace — make will dead-end` never emitted; green: `00:00 +8: All tests passed!` asserting `WARNING: FR-001 derives no unit behaviour`, `recorded as a manual declaration in tdd/traceability.md`, both remedies (`add a `traces:` line naming a declared contract row`, `add `**Type**: manual` under the FR`), the named artifact read back (`tdd/traceability.md` carries `manual (defaulted: no `traces:` binding)`), `isNot(contains('route: U1'))`, `isNot(contains('route: U2'))`, `isNot(contains('[fallback: no declared trace'))`, plus the preserved A1-heals + spec-marker invariants |
| T-U2 | every unbound FR announced individually; no dead-end tally for manual-routed FRs | PROVEN | green run asserts `WARNING: FR-001 derives no unit behaviour` AND `WARNING: FR-002 derives no unit behaviour`, `isNot(contains('will dead-end at make'))`; source-search confirms the tally string remains in `plan_command.dart` (`_printDeadEndTally`, built from two concatenated literals) but is unreachable from unbound FRs — see the dead-end-coverage gap below |
| T-U3 | per-FR warning scales to PLURAL unbound FRs (3 FRs → 3 warnings), still no tally | PROVEN | red: `3 behaviors will dead-end at make … (U1, U2, U3)` never emitted (verbatim transcript pinned in red-evidence.md); green: 3 per-FR warnings asserted + tally absence |

## Red-first evidence

Pre-fix run (HEAD `58ad4eed`, before ANY change to the test file):
`00:00 +5 -3: Some tests failed.` — the 3 failures are exactly the
stale pre-1484 assertions named in issue #1521; the 5 passes are the
healable-spec invariants this fix must not (and does not) disturb.
Full transcript pinned in `tdd/red-evidence.md`.

## Test-smell rubric

- assertion-roaming: none — every expectation is a targeted
  `contains`/`isNot(contains)` on the rendered plan output with a
  failure `reason` carrying the output.
- test-after: 0 — the red run predates any edit; the 3 behaviors were
  failing FIRST on pristine HEAD, then made green by expectation
  updates only.
- behavior/implementation coupling: the assertions pin the CONTRACT
  (warning block strings and their absence-of-tally counterpart) that
  feature 1484 renders, not internal call structure.
- magicfixture drift: none — fixtures `_unboundFrSpec` and the 3-FR
  inline spec are unchanged from the #1481 fix; only expectations
  moved to the post-1484 contract.

## Acceptance-criteria coverage

| criterion (issue #1521) | covered by |
| ----------------------- | ---------- |
| Option (a): expectations match feature 1484's manual routing (manual declaration warning, no dead-end tally for manual FRs) | T-U1, T-U2, T-U3 |
| Hard constraint: only the test file changed; no `plan_command.dart` routing change | `git diff --name-only HEAD` = the single test file (verified pre-commit) |
| Hard constraint: no other tests broken | chunked suite green; neighbor failure `bug_1432` proven pre-existing via stash run |
| `dart analyze` with no new warnings | `No issues found!` on the changed file |

## Gaps (environmental)

- No Flutter SDK in the sandbox → Flutter-tagged tests excluded with
  the same selector CI uses (`--exclude-tags flutter`); the target
  file and its neighbors are not Flutter-tagged.
- The `slow`-tagged nested suites are excluded by the same gate: 6
  directories match no tests under CI selectors (benchmark,
  integration, mock, plugins/helpers, plugins/tdd/helpers,
  plugins/tdd/scenarios) — recorded N/A, not failures.
- `bug_1432_platform_lane_rows_test.dart` (+1 -3) is red on PRISTINE
  HEAD (stash-verified) — pre-existing on `feat/1484-fr-manual-exemption`,
  out of scope for #1521; tracked separately so #1504 authors see it.

## Coverage gap (non-environmental, tracked)

- This change closes out the last test that referenced the fatal
  fallback class, so `plan_command.dart`'s dead-end machinery
  (`:1996` `if (!repairable) deadEnds.add(...)`, the `:2009` fatal
  route prefix, `_printDeadEndTally` at `:2028-2036`, and the
  `dead_end_behaviors` verdict key at `:1183`/`:1364`) now has no test
  that proves it live and none that proves it dead. Source analysis and
  three probe fixtures indicate it is unreachable from unbound FRs, but
  that is not proven. Tracked as #1537 — plan_command.dart changes are
  out of scope for this test-only PR per its hard constraints.
