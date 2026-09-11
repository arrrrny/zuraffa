# Bug TDD Test List — #1503 (mock create without --certify poisons the pipeline)

Feature ref: `.specify/bugs/1503-mock-create-certify-pipeline/`
Suite: `test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart`

| ID | Behavior | Kind | Contract pinned |
|----|----------|------|-----------------|
| U-1503a | The traced-entity arm (bug-#829 lane, `entityTraced` non-empty, non-stub) emits `mock create --name Task --certify`; the full plan argv stays `entity create -> mock create --certify -> tdd wire -> build` | unit (pure planner) | the mock step carries `--certify`, exactly |
| U-1503b | The declared `GenerationSurface.entityPipeline` arm (`_declaredPlan`, entity contract row) emits `mock create --name Task --certify` too | unit (pure planner) | both arms reconcile with the spec-1001 gate |
| U-1503c | EVERY `mock create` step the planner emits carries `--certify` — the engine never plans an uncertified mock for itself | unit (pure planner) | the self-contradiction is unreachable |
| U-1503d | The stub escape hatch still plans NO mock step (`make` instead) — `--certify` rides only the entity pipeline | unit (pure planner) | nothing outside the two mock arms changes |

Constraints honored by this list:

- Gate semantics, preflight logic, and the `mock create` command are NOT
  under test here — the fix surface is the planner's emitted argv only.
- Standalone `mock create` opt-in semantics are guarded by the untouched
  `create_mock_capability_test.dart` suite (regression-checked, 13/13).
