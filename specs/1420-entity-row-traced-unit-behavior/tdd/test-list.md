# TDD Test List — SPEC 1420 (entity pipeline engages at gen for row-only entity traces)

**Feature:** 1420-entity-row-traced-unit-behavior
**Tier:** fast (cloud-agent discipline — `dart test` default per `dart_test.yaml`); U-1420-R1 is driver-tier (`slow` tag, run explicitly)

## Unit behaviors (fast tier)

| id | test | asserts (SC) | state |
| -- | ---- | ------------ | ----- |
| U-1420-D1 | `declaredRoutingFor` on a Key-Entities row-only trace → RoutingDecision(kind unit, surface entityPipeline, entityName `SharedAttachmentType`, signature null) | SC-3 | GREEN |
| U-1420-D2 | `declaredSignatureFor` on the SAME spec → null (legacy contract unchanged — the delegation is byte-identical) | SC-3, SC-4 | GREEN |
| U-1420-D3 | `declaredSignatureFor` on a scalar contract-row trace → the resolved signature (delegation preserves the resolved path) | SC-3, SC-4 | GREEN |
| U-1420-D4 | `declaredRoutingFor` on a DOMAIN row with a signature → surface entityPipeline + non-null signature (the contract lane never enters the synthesis branch) | SC-4 | GREEN |
| U-1420-G1 | gen, entity EXISTS on disk: test asserts `expect(result, isA<SharedAttachmentType>())`, entity import emitted, NO vacuous-guard marker, subject renders `SharedAttachmentType subject_u1()` + entity import + provenance header `SharedAttachmentType() -> SharedAttachmentType` | SC-1a | GREEN |
| U-1420-G2 | gen, entity MISSING: test carries the traced `zfa:tdd: vacuous-guard` marker, subject return degrades to `Object?` with the header preserved, gen output carries NO `zfa:tdd: guard-only` warning token | SC-1b | GREEN |
| U-1420-G3 | gen, UNDECLARED (traces cell `FR-001` only): bare guard, NO marker, `zfa:tdd: guard-only` warning fires — the legacy fallback is byte-shaped unchanged | SC-4 | GREEN |
| U-1420-V1 | `vacuousGuardDeclaredTraceRemedyFor` wording: names re-gen from the declared trace + the hand step, never "add traces" / "no traces" | SC-2 | GREEN |

## Driver behaviors (slow tier — real RunDriverCore over the scripted fake zfa)

| id | test | asserts (SC) | state |
| -- | ---- | ------------ | ----- |
| U-1420-R1 | vacuous-green make stop, marker absent, traces cell resolves a declared entity row: output names the declared entity row class, carries the re-gen remedy, NEVER claims "no traces: to a declared contract row"; `stopped_at=U1:make` preserved | SC-2 | GREEN |

## Red evidence (recorded before implementation)

```
$ dart test test/plugins/tdd/services/declared_routing_1420_test.dart
declared_routing_1420_test.dart: Error: Couldn't resolve the package
  'zuraffa' ... 'package:zuraffa/src/plugins/tdd/services/declared_routing.dart'
  → Method 'declaredRoutingFor' isn't defined (T1 not yet implemented).

$ dart test test/plugins/tdd/commands/bug_1420_entity_row_gen_test.dart
U-1420-G1: Expected generated test to contain
  'expect(result, isA<SharedAttachmentType>())' → Actual: guard-only fallback
  ('expect(result, isNot(isA<UnimplementedError>()))') — the entity pipeline
  did not engage at gen (the issue's exact symptom).
U-1420-G2: Expected the vacuous-guard marker → Actual: bare guard, no marker.
U-1420-V1: 'vacuousGuardDeclaredTraceRemedyFor' isn't defined (T5 not yet
  implemented).
```
