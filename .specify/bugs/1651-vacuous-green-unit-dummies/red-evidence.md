# RED Evidence: 1651-vacuous-green-unit-dummies (#1651)

- **Date**: 2026-09-15
- **Tree**: `fix/1651-vacuous-green-unit-dummies` @ master c5ed519f (unfixed)
- **Command**: `dart test test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart`
  and `dart test test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart`

## Fast pin file — 5 passed / 4 failed (the failures ARE the bug)

| test | expected | actual |
| ---- | -------- | ------ |
| U1a bare type-only is vacuous | `contentIsVacuousGreen` == true | **false** — the detector counts `expect(result, isA<int>())` as a real assertion |
| U1b guard + type-only is vacuous | true | **false** |
| U1c legacy generated shape (capture + type-only, no marker) is vacuous | true | **false** |
| U2a–U2e value-discriminating sets stay real | false | false ✅ (guard rails hold pre-fix) |
| U3 writer emits the marker with the typed assertion | content contains `zfa:tdd: vacuous-guard` | **marker absent** — the pre-#1651 emission |

## E2E repro file (e2e tier) — failed at the marker pin, pre-refusal

The real `zfa tdd gen` output captured by the failure (the issue's
smoking gun, verbatim from the fixture):

```dart
final result = (() {
  try {
    return subject.subject_u1(0, 0);
  } on UnimplementedError catch (error) {
    return error;
  }
})();
expect(result, isA<int>());
```

- `Which: does not contain 'zfa:tdd: vacuous-guard'` — gen emitted the
  type-only assertion marker-less.
- Downstream of the failing pin (not reached in the red run): `make`
  certifies this pair after `func` fills `return 0;` — the exact
  #1651 complete-with-dummies flow (independently pinned as a FEATURE
  by `plan_traces_cell_1310_test.dart` U6 "make certifies green … the
  dummy `=> false;`" and by `bug_1538_void_guard_compile_test.dart` B1
  "a scalar contract asserts a real outcome — no marker").

## Why this is the right red

The red surface is the gen emission + the detector's classification —
the two seams the fix touches. The guard-rail tests (U2a–e) pass red AND
green, proving the fix cannot widen vacuity beyond the
dummy-satisfiable scalar class.
