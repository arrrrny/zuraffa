# Research: `zfa make engine` One-Shot Preset (issue #1109)

## R1: Idempotent DI registrations

**Decision**: Change the DI plugin's registration-call emission so every generated
`registerXxx` call is preceded by an unregister guard, and emit a `resetDependencies()`
function in the DI index file alongside `setupDependencies()`.

**Rationale**: The pilot sandbox hit `LoginUseCase is already registered inside GetIt`
(#1102-4) when `setupDependencies()` ran twice. Unregister-first registration makes the
setup function callable repeatedly (hot restart, test lanes, re-runs) without a throw.
`resetDependencies()` gives the test lane a clean teardown between cases.

**Alternatives considered**:
- Guard-only (`if (!getIt.isRegistered<T>())` skip): silent — a stale registration from a
  previous build would be reused, hiding generator drift. Unregister-first is fresher.
- Global `getIt.reset()` in setup: too blunt — it wipes registrations from other features
  and package-level registrars.

**Shape** (conceptual — exact emission via code_builder in `di_plugin.dart`):
`if (getIt.isRegistered<T>()) getIt.unregister<T>();` before each registration;
`resetDependencies()` unregisters each registered type (reverse-safe) without disposing
the locator itself.

## R2: Engine receipt — location and shape

**Decision**: Keep the existing `.zfa/engine.receipt.json` (`engine.v1`) as the internal
run artifact, and additionally write the issue-contract receipt to
`specs/<feature>/tdd/engine.receipt.json` with the shape #1014/CERT-GATE consumes:
`{entity, methods: [{name, mock_certified, mock_class}], source_files: [...]}`.

**Rationale**: Two consumers with two contracts. The `.zfa/` receipt is generator-internal
(digest, DI wiring, check outcome, options) and already read by existing tests. The
`specs/<feature>/tdd/` location is what the TDD/cert pipeline resolves by convention —
it must exist even when the feature directory is freshly created by the run, and it
carries `mock_class` (the certified mock's class name) which v1 lacks.

**Alternatives considered**:
- Replace v1 in place: breaks existing `.zfa/` readers and the engine-check tests keyed to v1.
- Symlink/duplicate path: symlinks are fragile cross-platform; a second writer call is trivial.

## R3: `dart analyze` as the third leg of `zfa engine check`

**Decision**: Add a static-analysis leg to `EngineChecker`: run `dart analyze` scoped to
the entity's engine-tree files (`EngineSlicePaths.sliceLibFiles()` ∪ `sliceTestFiles()`),
exit non-zero on findings, and surface each finding verbatim with its file path.

**Rationale**: AST-level checks prove wiring shape, not compilability. The success criteria
demand "runnable engine slice"; `dart analyze` on the slice files is the cheapest honest
proxy inside the check command. Scoped to slice files (not the whole project) so unrelated
project issues don't fail an engine check.

**Alternatives considered**:
- Whole-project analyze: slow on big apps and fails for pre-existing unrelated issues.
- Compile-only (`dart compile`): far too slow for a check command.

## R4: Trust-tier generator tests

**Decision**: Audit `test/plugins/{usecase,service,repository,datasource,mock}/` against
the "≥2 behavioral tests (structural + compile)" bar; add the missing behavioral tests
rather than new suites. Add behavioral tests for idempotency and `resetDependencies()`
under `test/plugins/di/`.

**Rationale**: All five suites already exist (verified); the gap is depth, not location —
matching the issue's "builds on #1003" note. Compile-level tests assert the generated
source parses/analyzes clean; structural tests assert the artifact tree and signatures.

## R5: Sandbox validation

**Decision**: Final proof runs in `~/zik_zak_test`: generate the engine slice for a real
entity with a reduced method set, run `zfa engine check`, and run the entity's tests.
Any zfa command misfire there triggers the AGENTS.md stop-on-roadblock rule.

**Rationale**: The issue explicitly demands live entity validation — the exact step that
invalidated the previous attempt (#1080).
