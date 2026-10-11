# Bug TDD Test List — #1503 (mock create without --certify poisons the pipeline)

Feature ref: `.specify/bugs/1503-mock-create-certify-pipeline/`
Suite: `test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart`

| ID | Behavior | Kind | Contract pinned |
|----|----------|------|-----------------|
| U-1503a | The traced-entity arm (bug-#829 lane, `entityTraced` non-empty, non-stub) emits `mock create --name Task --certify`, preceded by a BUILT `entity create -n Task --build`; the full plan argv is `entity create --build -> mock create --certify -> tdd wire -> build` | unit (pure planner) | the mock step carries `--certify` exactly, and the certify step always sees a built entity (review finding 1) |
| U-1503b | The declared `GenerationSurface.entityPipeline` arm (`_declaredPlan`, entity contract row) emits `mock create --name Task --certify` too, also preceded by a built `entity create` | unit (pure planner) | both arms reconcile with the spec-1001 gate and the built-entity precondition |
| U-1503c | Across EVERY planner arm shape (traced non-stub, traced stub, declared entityPipeline, declared function, declared presentation, undeclared entity-bait, undeclared function prose): any `mock create` step the planner emits carries `--certify` AND is preceded by a built `entity create` — a table-driven invariant, not a re-run of the two literal plans (review finding 3) | unit (pure planner) | the self-contradiction is unreachable, and the invariant table provably reaches both mock-emitting arms (non-vacuity pin) |
| U-1503d | The stub escape hatch still plans NO mock step (`make` instead) and no `--build` on its `entity create` — `--certify` rides only the certifying arms | unit (pure planner) | nothing outside the two mock arms changes |

Constraints honored by this list:

- Gate semantics, preflight logic, and the `mock create` command are NOT
  under test here — the fix surface is the planner's emitted argv only.
- Standalone `mock create` opt-in semantics are guarded by the untouched
  `create_mock_capability_test.dart` suite (regression-checked, 13/13).
