# TDD test list — Bug #1512 acceptance vacuous composition

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1512-a1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | acceptance | an undeclared acceptance row emits the parameterless void-safe capture | FR-1512, BehaviorTestWriter._captureInvocation | GREEN |
| A-1512-a2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | acceptance | a directly-injected scalar shape is inert for acceptance (no threaded args, no returned result) | FR-1512, BehaviorTestWriter._captureInvocation | GREEN |
| A-1512-a3 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | acceptance | a directly-injected entity-return shape is inert too | FR-1512, BehaviorTestWriter._captureInvocation | GREEN |
| A-1512-a4 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | acceptance | the paired subject is the parameterless void runner the test call matches | FR-1512, SubjectWriter acceptance stub | GREEN |
| A-1512-b1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the undeclared acceptance fallback carries the acceptance token, never the vacuous-guard marker | FR-1512, BehaviorTestWriter._deriveAssertion | GREEN |
| A-1512-b2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the acceptance fallback does not reuse the unit-lane comment block | FR-1512, vacuous_guard.acceptanceFallbackGuardComment | GREEN |
| A-1512-c1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | a plain scenario row plans the spec-052 composition lane (tdd compose → build) | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | an incidental capitalised word does not fabricate an entity | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c3 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | a capitalised word alone never drives the entity pipeline | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c4 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | an explicit `entity <Name>` prose signal plans the #758 entity pipeline (entity create → make → wire → build) | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c5 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | an explicit `create <Name>` prose signal plans the entity pipeline too | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c6 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | an explicit target wins the entity derivation | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c7 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the honest #758 refusal stays (CRUD prose, no entity) | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c8 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | non-acceptance rows keep the generic misfire | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-d1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the unit scalar capture is byte-for-byte (inferred annotation, threaded args, isA<T>, no marker, no acceptance token) | FR-1512, unit-lane guardrail | GREEN |
| A-1512-d2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the undeclared unit fallback guard stays unmarked (#1308 two-class dispatch) | FR-1512, unit-lane guardrail | GREEN |
| A-1512-e1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | integration | the emitted acceptance test+subject pair compiles and fails through an assertion (slow) | FR-1512, compile proof | GREEN |
