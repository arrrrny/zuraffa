# Red Evidence: 1521-1484-breaks-1481-fallback-tests (bug #1521)

Suite: `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
Run BEFORE any test change (branch `feat/1484-fr-manual-exemption`
HEAD `58ad4eed`, working tree clean, Dart 3.13.3 stable, Linux x64):

```
command: dart test test/plugins/tdd/commands/plan_command_bug_1481_test.dart
exit:    1
result:  00:00 +5 -3: Some tests failed.
```

Failing (the bug, reproduced by the pristine pre-1484 assertions) —
group `#1481: the two fallback classes are distinguishable`:

1. `a unit fallback renders the FATAL class (no declared trace, make
   will dead-end) while the scenario heals to declared`
2. `a single summary line tallies the dead-end behaviors (no scanning
   42 route lines)`
3. `the tally counts PLURAL dead-ends correctly`

Sample failure transcript (3-FR tally test, verbatim from this
session's run):

```
  Expected: contains '3 behaviors will dead-end at make — no declared contract trace (U1, U2, U3)'
    Actual: 'zfa tdd plan: WARNING: FR-001 derives no unit behaviour — no '
              'surviving `traces:` binding (a traces line whose tokens are all '
              'signature-shaped counts as unbound) and no `**Type**: manual` '
              'marker; recorded as a manual declaration in tdd/traceability.md.\n'
            '  --> fix: add a `traces:` line naming a declared contract row to '
              'derive an automated unit behaviour, or add `**Type**: manual` '
              'under the FR to declare the exemption explicitly.\n'
            ... (FR-002, FR-003 warnings identical in shape)
            '   route: A1 -> acceptance lane [declared: type marker, spec line 14]\n'
  Which: does not contain '3 behaviors will dead-end at make — no declared contract trace (U1, U2, U3)'
```

Key observations recorded from the red run:

- NO unit route line (`route: U1`) is emitted for the unbound FRs —
  feature 1484 removes the unit-lane row entirely; only the per-FR
  manual-declaration warnings remain.
- The old tally string `will dead-end at make` is absent from the
  output but NOT from `plan_command.dart` — it is still live code
  (`_printDeadEndTally`, built from two concatenated literals at
  `:2031-2035`, which is why a naive grep misses it), simply
  unreachable from unbound FRs; the class the tests assert is
  structurally unreachable.
- The acceptance scenario still heals in the same invocation
  (`route: A1 -> acceptance lane [declared: type marker, spec line 14]`)
  — the #1481 one-invocation-truth invariant is intact; only the
  fatal-class assertions are stale.

Passing (5): the five healable-spec tests — unaffected by the routing
flip, untouched by the fix.
