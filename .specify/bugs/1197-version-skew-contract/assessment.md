# Assessment — BUG 1197 generator/runtime version-skew contract

Date: 2026-09-06 · Branch: `fix/1197-version-skew-contract` · TDD: red → green (real)

## Diagnosis

The generator (master) emits `package:zuraffa/*` imports that the
published core does not provide. The coupling is structural: generated
artifacts are bound to ONE core version with no declared floor, no
runtime gate, no CI proof, and no doctor visibility.

Live pre-fix facts (see `tdd/red-evidence.txt`):

| Surface (emitted import) | master | tag v6.1.0 | Emission sites |
|---|---|---|---|
| `package:zuraffa/skin.dart` | present | **MISSING** | skin kit (`zfa skin kit`), view `--skin`, app shell `--skin-audit` |
| `package:zuraffa/simulation.dart` | present | **MISSING** | datasource DI registration files, simulation binding (spec 893) |
| `package:zuraffa/src/plugins/xray/xray_overlay.dart` | present | **MISSING** | app shell `--xray` (spec 036) |
| `package:zuraffa/zuraffa.dart`, `mock.dart` | present | present | everywhere (two-end stable) |

The #1180 hide-clause fix (via `ZuraffaBarrelExports`) already resolves
hide names against the target's installed core; the same
resolution principle (package_config → resolved core root) is the
authoritative source for availability. Version strings are unreliable
(the v6.1.0 tag shipped pubspec 6.0.1), so the contract gates on
AVAILABILITY with advisory floors.

## Fix design (implemented)

1. **Skew contract** (`lib/src/skew/skew_contract.dart`):
   - `supportedCoreFloor = '6.0.0'` — oldest supported core (two-end
     matrix bottom).
   - `coreApiFloors` — declared floors for `skin.dart`,
     `simulation.dart`, `src/plugins/xray/xray_overlay.dart`.
   - `InstalledCore` — resolves the target's ACTUAL core via
     `.dart_tool/package_config.json` (spec-correct: relative rootUri
     resolved against `.dart_tool/`), with a from-source generator
     fallback; version from the resolved core's pubspec (advisory).
   - `SkewContract.requireSurfaces(...)` — fail-open when the core is
     unresolvable (the #942/#1176 precedent), fail-closed with
     `VersionSkewException` (report + `--> fix: dart pub upgrade
     zuraffa`) when the resolved core lacks a required surface.
2. **Emission-site gates** (refuse BEFORE any file is written):
   - `zfa skin kit` → `skin.dart` (exit 1 + prescription)
   - `zfa app shell --skin-audit` → `skin.dart`
   - `zfa app shell --xray` → `src/plugins/xray/xray_overlay.dart`
   - `zfa view --skin` → `skin.dart`
   - `zfa di` (simulation-coupled datasource DI) → `simulation.dart`
   - `zfa mock` (simulation binding) → `simulation.dart`
3. **Receipt stamps** (`GenerationReceipt`): `min_core_version`
   (declared floor) + `generated_against_core` (resolved core
   version), nullable for back-compat; stamped on the make-path
   receipt and TDD generation receipts. The three hardcoded
   `generatorVersion: '6.1.0'` literals now track the `version` const
   (a future bump can never leave a stale literal).
4. **`zfa doctor` `runtime-skew` check**: the skew triangle — target
   pubspec pin vs installed core (package config) vs running
   generator — plus receipt-floor enforcement (a receipt generated
   against a newer core than installed = diagnosed downgrade, exit
   fail). Warn-only for advisory drift; feeds #1184's staleness case.
5. **CI two-end matrix** (`tools/run_skew_matrix.sh` +
   `.github/workflows/skew-matrix.yaml`): generate a real slice
   (entity → zorphy codegen → repository/datasource/usecase) against
   the OLDEST supported core (git tag v6.1.0 materialized via
   `git archive`) and the NEWEST master — `dart pub get` +
   `dart analyze` must be CLEAN on both ends; skin + simulation-DI
   refusal legs prove the gates live on the old end; receipt stamps
   asserted per leg.
6. **Flutter-consumer smoke gate** (`tools/flutter_consumer_smoke.sh`,
   #1189): a minimal Flutter consumer path-depends on the candidate
   core; `flutter pub get` + `flutter analyze` must be clean. Wired
   as `flutter-smoke-gate` in the skew-matrix workflow AND as a
   pre-publish `needs:` gate on release.yml's build job.

## Outcome

- RED: 11 failing tests + live reproduction (red-evidence.txt).
- GREEN: 29/29 skew tests pass; matrix script GREEN locally (all five
  legs); full fast suite 3,519 passed / 0 failed (85 chunks PASS,
  6 SKIP by tier, recorded in chunked-suite-results.txt).
- The matrix sweep is now a standing guard: any future emission of a
  `package:zuraffa/*` URI that the oldest supported core lacks must
  be floor-registered and gated, or CI goes red.
