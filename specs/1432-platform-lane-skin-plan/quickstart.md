# Quickstart: prove platform scenarios are first-class SKIN rows

## Prerequisites

- Repo checkout on the feature branch; `dart pub get` run.

## Reproduce the bug (pre-fix tree)

1. Create a hermetic spec with a `## Lanes` SKIN lane declaring an
   acceptance-typed scenario and a platform-typed acceptance scenario
   (each with a `**Type**` marker), e.g. `A8` acceptance + `A1` platform.
2. Run the planner over it:

   ```console
   $ zfa tdd plan <feature>
   route: A1 -> platform lane [declared: type marker, spec line N]   # log claims A1
   ```

3. **BUG (pre-fix)**: `specs/<feature>/tdd/04-SKIN.md`'s outer-loop table
   lists only the acceptance-typed id — A1 is absent while the log claimed
   its lane; `zfa tdd run`/`run-skin` then report green without it.

## Verify the fix (post-fix tree)

1. Same spec, same command: exit 0.
2. `04-SKIN.md`'s `## Outer loop: acceptance behaviors` table now carries
   the platform-typed row with the same columns as the acceptance row.
3. Every id in the route log appears in exactly the lane plan the log
   names (log ↔ artifact agreement).
4. A spec routing a kind no lane section renders (today: `theme`) exits
   non-zero with the #1432 refusal naming id/kind/criterion and writes no
   lane artifacts.
5. Regression: acceptance/widget/unit/ffi rows and the single-file plan
   path render byte-shape-identical to the pre-fix tree.

## Test entry points

```console
$ dart test test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart
$ dart test test/plugins/tdd/commands/plan_lanes_1000_test.dart   # lane-split regressions
```
