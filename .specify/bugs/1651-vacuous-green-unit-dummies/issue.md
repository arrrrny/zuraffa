# Bug Issue: tdd engine lane certifies vacuous greens (#1259 reproduces post-fix)

- **Slug**: 1651-vacuous-green-unit-dummies
- **Fetched**: 2026-09-15
- **Issue**: 1651
- **URL**: https://github.com/arrrrny/zuraffa/issues/1651
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

### Summary

`zfa tdd run` certifies **`result=complete`, `done=10`** on the zcalc probe (pure-Dart calculator, 2 acceptance + 4 unit + 4 contract behaviors) while **all four unit subjects on disk are func-scaffolded dummies that implement nothing**:

```dart
// lib/tdd/zcalc/u1_subject.dart (certified DONE, green evidence in cycle-log)
int subject_u1(int a, int b) {
  return 0;
}
```

```dart
// lib/tdd/zcalc/u4_subject.dart
double subject_u4(int a, int b) {
  return 0.0;
}
```

This is the exact bug class #1259 reported and was closed as fixed, but it reproduces verbatim on current `master` (f011e3fb). The post-#1259 generated unit test now asserts the return **type** in addition to the UnimplementedError guard, but the func dummy (`return 0;`) satisfies a type assertion, so the terminal green persists.

### Generated unit test (post-#1259 shape)

`zfa tdd gen U1` for FR-001 ("MUST add two integers via `Calculator.add` and return their sum", contract row `add(int a, int b) -> int`):

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

The assertion:

- calls the subject with the scaffold representative arguments `(0, 0)` — never with the spec's concrete scenario values (the spec's Given/When/Then says 2 and 3 → 5),
- checks only `isA<int>()`.

`make` then runs the func pass, which rewrites the throwing stub to `return 0;` (issue #1517 scaffold) → the test passes → green is certified and terminal. No entity, use case, or real `Calculator.add` ever exists; the engine receipt still reports `complete`.

Engine receipt at `specs/zcalc/tdd/04-engine-receipt.json`:

```json
{ "verdict": "green", "result": "complete", "counts": { "total": 10, "done": 10 } }
```

### Repro

1. `zfa setup zcalc --dart` (fresh package)
2. Spec with Layer Contracts row `Calculator: add(int a, int b) -> int`, FRs tracing `Calculator.add`, acceptance Given/When/Then with concrete values (full spec below).
3. `zfa tdd plan zcalc` → 10 behaviors (A1-A2, U1-U4, contract:A1-A4)
4. `zfa tdd run zcalc` (hand-remediate the two acceptance seams per the #1488 stop, implement the four contract seams per the #1007 stop — both designed hand steps)
5. Run completes: `result=complete pending=0 red=0 green=4 done=6` → final receipt `done=10`.
6. Inspect `lib/tdd/zcalc/u{1..4}_subject.dart`: all `return 0;`/`return 0.0;` dummies.

Spec used (the zuraffa-1.0 template; identical shape to the specs/041 fixtures):

```markdown
## Layer Contracts
**Domain**:
- `Calculator`: `add(int a, int b) -> int`, `subtract(...)`, `multiply(...)`, `divide(int a, int b) -> double`

### Functional Requirements
- **FR-001**: The engine MUST add two integers via `Calculator.add` and return their sum.
  traces: Calculator.add
...
## User Story 1 ... **Given** the integers 2 and 3, **When** `Calculator.add` is called, **Then** the sum 5 is returned. **Type**: acceptance
```

### Expected behavior

Per #1259's own expected-behavior block: *"green must require at least one assertion on the observable outcome named by the behavior description."* The current type-only assertion does not meet that bar — a `return 0;` dummy passes it.

Concrete asks:

1. **Derive example-based assertions from the spec's acceptance scenarios for unit behaviors.** The generator already parses Given/When/Then with concrete values (they drive the acceptance lane); the unit lane ignores them and invents `(0, 0)` + type check. For FR-001 the generated test should call `subject_u1(2, 3)` and expect `5`.
2. **Refuse terminal green for placeholder bodies.** make's func pass should reject (or at least flag) a dummy body whose test passes only via representative-argument type checks — e.g. require the test to contain at least one literal from the behavior description's scenario, or run the subject against the scenario values and require the assertion to discriminate (a `return 0;` dummy fails `2+3==5`).
3. Until then, the engine receipt for such behaviors should carry a `vacuous` marker rather than plain `done` — zik_zak-scale migrations will read `done=10` as "implemented", which is false.

### Why this matters for the zik_zak rebuild

The mission is to migrate @Developer/zik_zak by driving features through `zfa tdd run` to `complete`. With this gap, every feature's unit lane completes as theater: the receipt says done, the subjects are dummies, and nothing in the loop forces a real implementation. Only hand-written acceptance assertions (2 of 10 behaviors here) actually pin behavior.

### Environment

- zuraffa `master` f011e3fb (2026-09-15)
- macOS, Dart SDK 3.13.2
- Probe app + full logs: `/Users/arrrrny/Developer/zfa_tdd_probe/zcalc` (kept on disk for inspection; `run1..run5.log`, `specs/zcalc/tdd/journal.json`, `cycle-log.md`)

## Comments

None.
