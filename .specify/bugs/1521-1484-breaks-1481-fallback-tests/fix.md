# Fix: 1521-1484-breaks-1481-fallback-tests (bug #1521)

## Change surface (hard constraints honored)

- `test/plugins/tdd/commands/plan_command_bug_1481_test.dart` — ONLY
  file touched (+94/−39 lines).
- `lib/src/plugins/tdd/commands/plan_command.dart`: UNCHANGED — feature
  1484 routing behavior is untouched.
- All other test files: UNCHANGED.
- One PR per bug, `Closes #1521`.

## Remediation path chosen

Issue option (a): update the #1481 dead-end-tally expectations to match
feature 1484's manual routing. The three failing tests asserted the
pre-1484 fatal unit-fallback class (`[fallback: no declared trace —
make will dead-end]` + the `N behaviors will dead-end at make` tally),
which feature 1484 deliberately put out of reach for unbound FRs —
they now route to manual declarations with a per-FR warning and remedy
line (`plan_command.dart` lines 265–275).

## What changed

All three edits are in the group `#1481: manual routing replaced the
fatal unit-fallback class`; the library doc comment gained a short
feature-1484 note so the file's own contract documentation stays
truthful.

1. **T-U1** (was `a unit fallback renders the FATAL class …` → now
   `an unbound FR routes to a manual declaration (no unit route line,
   no fallback class) while the scenario heals to declared`):
   - asserts the feature-1484 warning block: `WARNING: FR-001 derives
     no unit behaviour`, `recorded as a manual declaration in
     tdd/traceability.md`, and BOTH remedies (`add a `traces:` line
     naming a declared contract row`, `add `**Type**: manual` under
     the FR`);
   - asserts the retired class is gone: `isNot(contains('route:
     U1'))`, `isNot(contains('route: U2'))` and
     `isNot(contains('[fallback: no declared trace'))`;
   - reads back the artifact the warning names: `tdd/traceability.md`
     carries `manual (defaulted: no `traces:` binding)`;
   - keeps the #1481 invariants: A1 still heals to
     `[declared: type marker` in the same invocation and the spec on
     disk still carries `**Type**: acceptance`.
2. **T-U2** (was `a single summary line tallies the dead-end behaviors
   …` → now `every unbound FR gets its own manual-declaration warning
   (no dead-end tally for manual-routed FRs)`): asserts both FR-001
   and FR-002 warnings are rendered and `isNot(contains('will dead-end
   at make'))` — manual-routed FRs never reach make as automated unit
   behaviors, so the tally no longer applies.
3. **T-U3** (was `the tally counts PLURAL dead-ends correctly` → now
   `the per-FR warning scales to PLURAL unbound FRs correctly`): the
   3-FR fixture asserts one warning per FR (FR-001, FR-002, FR-003)
   and no dead-end tally.

## What was deliberately NOT done

- No production change: resurrecting the fatal fallback class (issue
  option b) would undo feature 1484's core safety property — a
  defaulted FR must never reach `make` as an automated unit row that
  cannot honestly pass.
- No edits to the passing five tests: the healable-spec tests (marker
  migration, one-invocation truth, artifact/stdout agreement,
  announcement, `--no-emit-markers` repairable class) are unaffected
  by the routing flip and remain green unchanged.
