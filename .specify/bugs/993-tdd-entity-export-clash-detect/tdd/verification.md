---
feature: .specify/bugs/993-tdd-entity-export-clash-detect (bug #993, pinned per bug extension TDD mode)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
mutation_score: 3/3 caught # scope: the plan-time entity/export clash gate in plan_command.dart — manual deliberate mutants (gate disabled, fix line dropped, fail-open flipped to fail-closed), each killed by a named test
mutants_survived: 0
suite: "bug_993_plan_entity_export_clash_test.dart 7/7 (6 in-process + 1 real-CLI subprocess); chunked fast suite (tools/run_tests_chunked.sh semantics, chunk list from its DRY_RUN, 75 chunks): 70 PASS / 4 SKIP (no fast-tier tests by design) / 0 FAIL = 2902 passed, plus the two folders the chunker's >40-file split skips (test/commands 132 passed, test/plugins/tdd/services 562 passed) = 3596 passed / 0 failed; dart analyze: byte-for-byte identical to stashed master (345 pre-existing issues, none introduced); dart format .: 0 diffs remaining (only the new test file needed formatting; git diff --stat shows exactly the gate + the new test)"
---

# TDD Verification: bug #993 — `zfa tdd plan` detects entity/zuraffa-export clashes early, not at run-time

**Verdict: PASS.** The red→green cycle is real, every behavior is covered by a
test that failed against the pre-fix tree with the exact #993 signature, all
three deliberate mutants were killed, and the end-to-end contract is proven
twice: in-process through the CLI runner and through the real CLI as a
subprocess.

Provenance note (honest): the runbook asserted
`.specify/bugs/993-tdd-entity-export-clash-detect/issue.md` and
`assessment.md` were already committed; no such records exist in the tree
(200+ slugs searched). The bug context was taken from the runbook's
section-3 record itself (root cause, remediation menu, hard constraints) and
verified against the code before any test was written; the sibling record
`942-entity-name-collides-framework-export` supplied the repo's record
conventions. This file is the only artifact created under the slug.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B1 — plan refuses a Key Entity whose name matches a zuraffa export: exit 2, the clash named, a `--> fix:` rename suggestion, and NO artifacts (test list + traceability matrix) | PROVEN | RED captured (pre-fix run, this session): `Expected: <2> Actual: <0>` — plan exited 0 and WROTE `test-list.md` (`extracted 1 Key Entity(ies): AgentState`). GREEN post-fix: exit 2, output carries `entity/export clash — 1 Key Entity(ies) collide with zuraffa framework exports`, the `--> fix: rename the entity in the spec's Key Entities section, e.g. \`AgentStateEntity\` …` line, and neither `tdd/test-list.md` nor `tdd/traceability.md` exists. |
| B2 — the refusal names the framework file the clash comes from | PROVEN | RED captured (pre-fix): no refusal at all. GREEN post-fix: output contains `package:zuraffa/src/agent/runtime/state_storage.dart` (the declaring file of the `AgentState` export), pinning the collision for the spec author. |
| B3 — a mixed Key Entities section (one clashing + one clean) still refuses the whole plan | PROVEN | RED captured (pre-fix): `Expected: <2> Actual: <0>`, plan wrote the list with `extracted 2 Key Entity(ies): AgentState, KillSwitchLog`. GREEN post-fix: exit 2, no test list — phase-0 would halt on `AgentState` regardless of the clean entity. |
| B4 — no false refusals: clean names plan unchanged, entity-less specs are unaffected, and an unresolvable export surface never refuses (fail-open, the #942 contract) | PROVEN | Three named tests: `AgentSessionSnapshot` plans successfully WITH a resolvable surface (the gate ran and found no clash); a spec without Key Entities plans unchanged; a clashing name (`AgentState`) with an UNRESOLVABLE surface still plans exit 0 — pinning fail-open deliberately (under `dart test` the script-path fallback is dead by harness construction, so the unresolvable path is exercised for real). |
| B5 — end-to-end: the REAL CLI refuses the clashing plan (subprocess) | PROVEN | `runZfaSource(['tdd','plan','013-agent-modes-killswitch','--project',ws])` → exit 2, `--> fix:`, the state_storage source line, no test list on disk. The fixture resolves the surface the way every real project does (`.dart_tool/package_config.json` `zuraffa` entry — the primary resolution path, the config `pub get` writes). |

### The bug's own repro, before and after

Pre-fix RED (captured this session, pre-change tree): plan wrote the test
list silently (`zfa tdd plan: wrote … with 1 acceptance + 1 unit behaviors`;
`extracted 1 Key Entity(ies): AgentState`), and `zfa tdd run
013-agent-modes-killswitch --timeout 5` then halted exactly as the bug
reports:

```
[run] phase-0 entity AgentState -> failed
   ❌ Cannot create entity "AgentState": the name collides with the zuraffa
      framework export "AgentState" (package:zuraffa/src/agent/runtime/state_storage.dart).
   --> fix: rename the entity, e.g. `zfa entity create AgentStateEntity --fields=...` ...
zfa tdd run: phase-0 entity failed (exit 1) — the run stops before any
behavior is driven (bug #829).
run: … result=runner-error … stopped_at=phase-0:entity
```

Post-fix GREEN: `zfa tdd plan` refuses BEFORE the run is ever attempted —
same surface, same rename contract, no artifacts, exit 2.

## Deliberate mutants (all killed, run against the fixed tree)

| Mutant | Change | Killing test | Observed |
| --- | --- | --- | --- |
| M1 | plan: `if (false && clashes.isNotEmpty)` — gate disabled | B1 + B2 + B3 (the three clash-expectation tests) | FAIL — plan reverted to the bug signature: exit 0, artifacts written (`+3 -3: Some tests failed`) |
| M2 | plan: the `--> fix:` rename print dropped | B1 (`contains('--> fix:')`) | FAIL — refusal lost its machine-actionable fix line (`+0 -1`) |
| M3 | plan: fail-open flipped to fail-closed — an unresolvable surface now refuses (`clashes.isNotEmpty \|\| surface == null`) | B4 (`fail-open` test) | FAIL — the clashing-name/unresolvable-surface case was refused, breaking the #942 fail-open contract (`+0 -1`) |

## Acceptance criteria (from the #993 record)

1. **Detect the clash at plan time and surface `--> fix:` with a rename
   suggestion** — proven: the gate fires inside `zfa tdd plan` before any
   artifact is written (B1–B3, B5), reusing the SAME
   `FrameworkExportSurface` the run-time preflight uses
   (`surface.lookup(name)` per entity) — the plan-time net is an earlier
   net, never a weaker one.
2. **Do not weaken the clash detection itself** — proven: the run-time
   preflight in `entity_command.dart` is untouched (`git diff` touches only
   `plan_command.dart`); the run-time refusal was re-demonstrated verbatim
   against the pre-fix-style artifact (see repro above), and M3 pins that
   the plan-time gate preserves the fail-open semantics instead of
   over-refusing.
3. **One PR for this bug only** — 2 files touched: the gate (+43 lines in
   `lib/src/plugins/tdd/commands/plan_command.dart`) and the new test file.
   The remediation menu's other options (driver-proposed renamed plan,
   `--allow-namespace-overlap`) are deliberately not taken — the plan-time
   gate alone satisfies the hard constraints with the minimal diff.

## Suite accounting (real runs, this session)

- Chunked fast suite — run with the exact per-chunk semantics of
  `tools/run_tests_chunked.sh` (same `dart test <dir> --exclude-tags flutter`
  command, same kernel-cache cleanup between chunks, same empty-folder skip
  rule), segmented because this sandbox kills background processes between
  tool calls: **75 chunks → 70 PASS / 4 SKIP / 0 FAIL = 2902 passed**. The
  two folders the chunker's `>THRESHOLD` split skips were run explicitly:
  `test/commands` → 132 passed (0 failures — the pre-existing
  pristine-identical A2 failure recorded under #942 no longer reproduces on
  this tree); `test/plugins/tdd/services` → 562 passed. **Total: 3596
  passed / 0 failed.**
- `dart analyze`: byte-for-byte identical to stashed master (345 pre-existing
  issues — Flutter-dependent `examples/` errors and info-level lints that
  reproduce on master without changes).
- `dart format .`: 0 diffs remaining after formatting the new test file;
  `dart format --set-exit-if-changed` on both touched files is clean, and
  `git diff --stat` shows exactly the two intended files.
