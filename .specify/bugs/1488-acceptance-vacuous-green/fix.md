# Fix — #1488 acceptance lane certifies vacuous greens

## The change (one gate, two comment blocks)

`lib/src/plugins/tdd/commands/make_command.dart` — make step 3c:

```dart
// pre-#1488:
if (vacuousRowKind == BehaviorKind.unit && scaffoldCheckFile.existsSync()) {

// post-#1488:
final vacuousLaneScoped = vacuousRowKind == BehaviorKind.unit ||
    vacuousRowKind == BehaviorKind.acceptance;
if (vacuousLaneScoped && scaffoldCheckFile.existsSync()) {
```

`contentIsVacuousGreen` (vacuous_guard.dart) is UNTOUCHED — its detection
already covered the acceptance guard-only shape; only the call-site scope
was wrong.

Comment blocks updated (no behavior change):

- `make_command.dart` step-3c doc: records the widened scope, WHY
  acceptance is in scope (044 ownership contract → the test stays
  guard-only for its whole life; the run driver's marker-absent
  `stopped_at=<id>:make` class already names this stop), and the
  fail-open contract for kindless/legacy rows.
- `behavior_test_writer.dart` `_captureInvocation` doc: the old text
  said the refusal "is unit-scoped by design … the guard certifies
  green" after compose — factually wrong post-#1488. Now states the
  guard-only acceptance test is the lane's correct RED surface and the
  designed hand step (a real outcome assertion) is required before any
  green certifies.

## Test changes

- NEW `test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart`:
  - A1 (the bug): guard-only acceptance test + certified red +
    non-throwing subject → make refuses: exit 1, `outcome=vacuous-green`,
    no green evidence. RED pre-fix (certified `outcome=skipped` green),
    GREEN post-fix.
  - A2: the same acceptance test with an outcome assertion
    (`expect(result, isNull)` — the void-safe capture's honest
    completion-surface assertion) still certifies green — the refusal
    keys on the assertion set, never the lane.
  - A3: kindless/legacy rows (no test list) keep the fail-open skip.
  - U1: unit-lane refusal unchanged (#1259 U1 mirror).
- `bug_1259_vacuous_green_test.dart` U3 inverted: acceptance rows are IN
  the refusal scope (exit 1, `outcome=vacuous-green`, no green
  evidence); header test map updated with the inversion citation.
- `bug_1162_bug_subject_green_path_test.dart` A-1162e inverted: the
  unexpressible acceptance make is REFUSED vacuous-green BEFORE the
  composition fallback runs (fake-zfa log asserts no compose dispatch);
  header contract line updated.

## Verification

- `dart analyze` on the five changed files: **No issues found!**
- `dart format .`: 2764 files, 0 changed (tree format-clean).
- Fast suite, chunked (`tools/run_tests_chunked.sh` chunk list + the
  loose `test/plugins/tdd/*.dart` files the subdir split skips): every
  chunk green — incl. `test/cli`, `test/commands`,
  `test/plugins/tdd/commands` (+ the loose-files chunk `+519 All tests
  passed!`, the services dir `+945 All tests passed!`, remaining files
  `+488 All tests passed!`).
- Slow tdd scope (`--preset=all`, per file): `bug_1488` +4, `bug_1162`
  +5, `bug_1259` U1/U2/U3 green, `make_command_test` +33, `run_command`
  +50, `make_command_1036` +5, `bug_1331` +8, `bug_1345` +5 (proves the
  widened gate does NOT pre-empt the legitimate compose re-entry),
  `bug_1430` +14, `bug_964` +33, `compose_command` +15 — every non-passing
  test reproduced on the CLEAN tree (`git stash`) and classified
  pre-existing environmental (gen-emission isolate failures / sandbox
  resource kills) or unrelated test-impl drift (#871, #1397, help text).
  Zero new failures.
