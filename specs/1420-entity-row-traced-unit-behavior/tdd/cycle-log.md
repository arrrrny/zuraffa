# TDD Cycle Log — SPEC 1420 (entity pipeline engages at gen for row-only entity traces)

**Feature:** 1420-entity-row-traced-unit-behavior
**Issue:** #1420
**Tree at RED:** 71396336 (WIP: spec-kit artifacts) + new tests only

## Cycle 1 — U-1420-D1..D4 (declared_routing: the full decision seam)

### RED (before implementation)

```
$ dart test test/plugins/tdd/services/declared_routing_1420_test.dart
  declared_routing_1420_test.dart [E] — loading failed:
    Error: Member not found: 'DeclaredRouting.declaredRoutingFor'
    Error: Undefined name 'BehaviorKind' (import fixed; re-run below)
  → the seam does not exist yet (T1 not implemented)
```

### GREEN

```
$ dart test test/plugins/tdd/services/declared_routing_1420_test.dart
00:00 +4: All tests passed!
  U-1420-D1 — row-only entity trace → RoutingDecision(kind unit,
              surface entityPipeline, entityName SharedAttachmentType,
              signature null)
  U-1420-D2 — legacy declaredSignatureFor on the SAME spec → null
              (the delegation is byte-identical)
  U-1420-D3 — legacy declaredSignatureFor on a scalar trace → login
  U-1420-D4 — DOMAIN row with a signature → entityPipeline + signature
              (never the synthesis branch)
```

## Cycle 2 — U-1420-G1..G3 (gen: the entity pipeline engages)

### RED (before implementation — the issue's symptom, assertion-level)

```
$ dart test test/plugins/tdd/commands/bug_1420_entity_row_gen_test.dart
U-1420-G1 [E]:
  Expected: contains 'expect(result, isA<SharedAttachmentType>());'
  Actual:
    final result = (() {
      try {
        return subject.subject_u1();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));   ← guard-only fallback,
                                                          int subject_u1()
U-1420-G2 [E]: Expected the traced vacuous-guard marker → Actual: bare guard
U-1420-G3 — PASSED pre-fix (regression pin: the undeclared fallback was
            already correct and must stay so)
00:00 +1 -2: Some tests failed.
```

### GREEN

```
$ dart test test/plugins/tdd/commands/bug_1420_entity_row_gen_test.dart
00:01 +3: All tests passed!
  U-1420-G1 — entity EXISTS: isA<SharedAttachmentType>() + entity import,
              no marker; subject renders `SharedAttachmentType subject_u1()`
              with the `SharedAttachmentType() -> SharedAttachmentType`
              provenance header (wire's stub-header seam)
  U-1420-G2 — entity MISSING: the traced `zfa:tdd: vacuous-guard` marker,
              `Object?` degradation, header preserved, gen warning SILENT
  U-1420-G3 — undeclared: legacy guard-only fallback + warning (unchanged)
```

## Cycle 3 — U-1420-V1 (the declared-trace remedy wording)

### RED

```
$ dart test test/plugins/tdd/services/vacuous_guard_1420_test.dart
  vacuous_guard_1420_test.dart [E] — loading failed:
    Error: Method not found: 'vacuousGuardDeclaredTraceRemedyFor'
```

### GREEN

```
$ dart test test/plugins/tdd/services/vacuous_guard_1420_test.dart
00:00 +1: All tests passed!
```

## Cycle 4 — U-1420-R1 (driver: the stop never claims "no traces")

### RED (design-level: the stop message hardcodes the false claim pre-fix;
### the driver suite pins the post-fix transcript)

The pre-fix stop prints, verbatim (`run_driver_core.dart`):
"the behavior is fallback-routed (no traces: to a declared contract row)"
+ "add traces: <ContractRow> to the FR" — false for the declared entity-row
trace the suite seeds, and impossible to follow (entity rows declare no
methods).

### GREEN

```
$ dart test --preset=all test/plugins/tdd/bug_1420_vacuous_stop_declared_trace_test.dart
00:05 +1: All tests passed!
  U-1420-R1 — stop stays `stopped_at=U1:make` (machine contract preserved);
              the transcript names the declared entity row
              `SharedAttachmentType`, carries the re-gen remedy
              (`zfa tdd gen U1`), and NEVER claims
              "no traces: to a declared contract row" / "add traces:"
```
