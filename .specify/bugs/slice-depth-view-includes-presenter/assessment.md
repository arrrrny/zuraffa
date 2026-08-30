# Bug Assessment: `zfa slice cut --depth view` mirrors the presenter layer

- **Slug**: slice-depth-view-includes-presenter
- **Created**: 2026-08-30
- **Source**: pasted text (failing test output from `dart test`)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

```text
Expected: not contains 'lib/src/presentation/pages/product/product_presenter.dart'
  Actual: Set:[
            'main_slice.dart',
            'SLICE.md',
            'slice.yaml',
            'pubspec.yaml',
            'lib/src/mocks/mock_product.dart',
            'lib/src/mocks/mock_product_presenter.dart',
            'lib/src/presentation/pages/product/product_view.dart',
            'lib/src/presentation/pages/product/product_controller.dart',
            'lib/src/presentation/pages/product/product_state.dart',
            'lib/src/presentation/pages/product/product_presenter.dart',
            'lib/src/presentation/widgets/primary_button.dart',
            'lib/src/presentation/widgets/index.dart',
            'lib/src/domain/entities/product/product.dart',
            'lib/src/di/slice_di.dart'
          ]
```

## Symptom

At `--depth view`, the sliced file set still includes the **presenter** layer
(`product_presenter.dart` and `mock_product_presenter.dart`). Expected: only the
view/controller/state layers plus the entry, mocks, and `slice_di.dart`.

## Reproduction

```bash
dart test test/plugins/slice/slice_depth_test.dart
```

Or manually: `dart run bin/zfa.dart slice cut product_feature --entry product --depth view`
and inspect `.zuraffa/slices/product_feature/lib/src/presentation/pages/product/`.

## Suspected Code Paths

- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart` — the depth filter / dependency walk that decides which layers to mirror for `--depth view`. The presenter is being pulled in though it is deeper than the view layer.
- `lib/src/plugins/slice/engine/service_locator_analyzer.dart` — boundary/dependency analysis that may be traversing into the presenter when resolving the entry's dependencies.

## Root Cause Hypothesis

The `--depth view` filter includes the presenter layer in the mirrored set.
Either the depth ordering treats `view` as including `presentation` wholesale
(instead of view/controller/state only), or the dependency walk follows the
controller→presenter edge and re-includes the presenter. Confidence: **medium**
— needs confirmation of where the presenter edge is added to the slice graph.

## Proposed Remediation

**Preferred**: Tighten the `--depth view` layer filter so it stops at
view/controller/state and excludes the presenter; verify the dependency walk does
not re-include the presenter via the controller edge.

**Files likely to change**:
- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart`
- `lib/src/plugins/slice/engine/service_locator_analyzer.dart`

**Tests to add or update**:
- `test/plugins/slice/slice_depth_test.dart` (the failing acceptance test A13/T099) already covers this; keep it as the guard.

## Risks & Considerations

- Changing depth filtering affects `view`/`presentation`/`feature`/`full` tiers — confirm the other tiers still include the presenter when appropriate.
- Exclude only the concrete `product_presenter.dart` at `view` depth. Retain
  `mock_product_presenter.dart`, including its `MockProductPresenter` generation
  and the corresponding `slice_di.dart` binding.

## Open Questions

- [NEEDS CLARIFICATION: confirm whether the presenter is pulled in by the depth filter or by a dependency-walk edge from the controller.]

## Failing tests covered by this assessment

1. `test/plugins/slice/slice_depth_test.dart: A13 (T099): depth view — view/controller/state, no deeper layers`
