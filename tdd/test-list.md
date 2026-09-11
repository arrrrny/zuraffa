# TDD test list — Bug #1512 acceptance vacuous composition

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1512-a1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | acceptance | a declared scalar contract threads the declared args into the call site and returns the result — never the empty-call discard | FR-1512, BehaviorTestWriter._captureInvocation | GREEN |
| A-1512-a2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | acceptance | a declared entity return (Object? degradation) threads args and captures the result | FR-1512, BehaviorTestWriter._captureInvocation | GREEN |
| A-1512-a3 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | acceptance | a declared void return keeps the void-safe capture form while still threading declared args | FR-1512, BehaviorTestWriter._captureInvocation | GREEN |
| A-1512-b1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | a declared scalar outcome asserts isA<T>() — mechanically non-vacuous | FR-1512, BehaviorTestWriter._declaredAssertion | GREEN |
| A-1512-b2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | a declared entity outcome carries the vacuous-guard marker seam | FR-1512, vacuous_guard.contentIsVacuousGreen | GREEN |
| A-1512-b3 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | an undeclared acceptance fallback guard carries the marker seam — never silent vacuity | FR-1512, BehaviorTestWriter._deriveAssertion | GREEN |
| A-1512-c1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | a plain scenario row plans the spec-052 composition lane (tdd compose → build) | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | a row naming an entity plans the #758 entity pipeline (entity create → make → wire → build) | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c3 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | an explicit target wins the entity derivation | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c4 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the honest #758 refusal stays (CRUD prose, no entity) | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-c5 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | non-acceptance rows keep the generic misfire | FR-1512, GenerationPlanner.plan | GREEN |
| A-1512-d1 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the unit scalar capture is byte-for-byte (inferred annotation, threaded args, isA<T>, no marker) | FR-1512, unit-lane guardrail | GREEN |
| A-1512-d2 | test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart | unit | the undeclared unit fallback guard stays unmarked (#1308 two-class dispatch) | FR-1512, unit-lane guardrail | GREEN |
