# Issue — #1488 tdd: the acceptance lane certifies vacuous greens

## Dogfood evidence

`zfa tdd run 001-todo-app --timeout 25` on the todo host:

```
A9 gen -> ok
A9 verify-red -> certified
A9 make -> green            ← guard-only assertion set, certified anyway
run: green=1 (proof-free success)
```

An acceptance behavior whose paired test's ONLY assertion is the
UnimplementedError guard is certified green by `zfa tdd make` and the false
green is persisted into the run state / cycle log — the exact vacuity class
issue #1259 was raised to eliminate.

## Root cause

`vacuous_guard.dart` — `contentIsVacuousGreen` correctly returns `true` for
acceptance guard-only tests (the content backstop strips both guard shapes:
`expect(x, isNot(isA<UnimplementedError>()))` and the throwsA variant the
acceptance fixtures carry). But the make-side call site is gated on
`BehaviorKind.unit` only:

```dart
// make_command.dart, step 3c (pre-#1488):
if (vacuousRowKind == BehaviorKind.unit && scaffoldCheckFile.existsSync()) {
  final testContent = await scaffoldCheckFile.readAsString();
  if (contentIsVacuousGreen(testContent)) { /* refuse */ }
}
```

So an acceptance row with a passing guard-only test skips the refusal,
reaches the drift check (issue #694 skip transition) or the composition
fallback's post-compose re-run, and certifies green with zero assertions on
any observable outcome.

## Why the acceptance lane cannot be exempt

- The composition lane NEVER touches the paired test file (the 044
  ownership contract — `compose_command.dart` library doc, item 5). A
  guard-only acceptance test stays guard-only for its whole life; its
  post-compose pass is proof-free by construction (a no-op composed body
  that merely does not throw flips it green).
- The run driver already classifies this exact stop honestly: a make
  `vacuous-green` outcome on a marker-absent test is the fallback-routed
  `stopped_at=<id>:make` class with the composed-lane remedy
  (`run_driver_core.dart`, issues #1308/#1512). Only the make gate was
  missing — the run driver was ready to stop, make never refused.
- The pre-#1488 exemption was a legacy scoping decision pinned in
  `bug_1259_vacuous_green_test.dart` U3 ("acceptance rows keep the legacy
  skip transition") and in `bug_1162_bug_subject_green_path_test.dart`
  A-1162e (the stub-only compose green). Issue #1488 closes both.

## Expected

Acceptance rows with guard-only assertion sets refused (never green) —
same refusal surface, same remedy shape, as the unit lane.

## Related

- #1259 — the unit-lane vacuous-green refusal (the gate this fix widens)
- #1512 — the acceptance fallback token + composition-lane classification
- #1308 — the run driver's two-class vacuous-green stop (marker-present →
  `:hand`, marker-absent → `:make`); consumes this fix's outcome
- #912 — the widget lane's scaffolded refusal (the original analogue)
