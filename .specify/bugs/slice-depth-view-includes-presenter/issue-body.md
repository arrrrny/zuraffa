## Symptom

At `--depth view`, the sliced file set still includes the concrete presenter
(`product_presenter.dart`). Expected: view/controller/state plus the entry,
mocks (including `mock_product_presenter.dart`), and `slice_di.dart`.

## Reproduction

```bash
dart test test/plugins/slice/slice_depth_test.dart
```

## Suspected Code Paths

- `lib/src/plugins/slice/capabilities/cut_slice_capability.dart` — the `--depth view` filter / dependency walk that decides which layers to mirror.
- `lib/src/plugins/slice/engine/service_locator_analyzer.dart` — may traverse the controller→presenter edge and re-include the presenter.

## Root Cause Hypothesis

The `--depth view` filter includes the presenter layer in the mirrored set
(either through the depth ordering or a dependency-walk edge from the controller).
Confidence: **medium** — confirm where the presenter edge is added to the slice graph.

## Severity

medium — depth filtering is incorrect, but does not crash; 1 test red.

## Failing tests covered

- slice_depth_test.dart: A13 (T099): depth view — view/controller/state, no deeper layers

Assessment: .specify/bugs/slice-depth-view-includes-presenter/assessment.md
