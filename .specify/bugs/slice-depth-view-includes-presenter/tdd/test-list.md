# Test List: slice-depth-view-includes-presenter (#597)

```yaml
---
feature: slice-depth-view-includes-presenter # bug slug (.specify/bugs/<slug>/)
loop: inside-out # depth classification is an internal filter; A13 covers the outer entry point
profile: .specify/memory/tdd-profile.md
spec_criteria: 3 # issue acceptance + assessment remediation criteria
planned_at: 11de4bfc
updated_at: 11de4bfc
suite_baseline: green # A13/A14/A15 green at HEAD 11de4bfc — see Baseline note
---
```

## Reproduction note (read first)

The bug record's failing state (assessment.md "Report") does **not** reproduce
at HEAD `11de4bfc`: A13 (T099) passes and a manual
`zfa slice cut product_feature --entry product --depth view` excludes
`product_presenter.dart`. The remediation the assessment proposes is already
implemented in HEAD (the `interfaceIncluded` guard in
`cut_slice_capability.dart` and the walker's layer gates, merged with PR #595
~30 min before the issue was filed). What DOES reproduce at HEAD is the
failure mode the issue names — "the depth ordering treats view as including
presentation wholesale": `classifyLayer` classified a presenter file outside
`pages/` as `presentation_shared`, which `--depth view` mirrors. The cycles
below drive that residual gap red→green and pin the tiers the assessment
requires confirming.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| A1 | `--depth view` includes view/controller/state (+shared widgets, existing mocks, slice_di mock binding) and no presenter, usecases, entities, or data | Issue #597 acceptance | example | BASELINE | `test/plugins/slice/slice_depth_test.dart::A13 (T099)` (pre-existing; green at baseline, guard landed in #595) |
| A2 | `--depth presentation` includes the presenter and still excludes domain and data, with usecases mocked and wired through slice_di | Assessment: "other depth tiers still include the presenter" | example | BASELINE | `test/plugins/slice/slice_depth_test.dart::A13b (597)` (new; characterization of correct tier behavior — no test covered this tier before) |

## Inner loop: unit behaviors

### `lib/src/plugins/slice/models/file_graph.dart`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | A presenter file anywhere under `lib/src/presentation/` classifies as the `presenter` layer (not `presentation_shared`), so `--depth view` excludes it wherever it lives | Issue #597 root cause ("depth ordering treats view as including presentation wholesale") | example | DONE | `test/plugins/slice/models/file_graph_test.dart::a presenter anywhere under presentation/ is the presenter layer (597)` |
| U2 | `layerAllowedAtDepth` pins the four-tier table: view excludes presenter/domain/data/di; presentation adds presenter; feature adds domain+di; full includes all | Assessment: "confirm the other depth tiers" | example | BASELINE | `test/plugins/slice/models/file_graph_test.dart::layerAllowedAtDepth ...` (4 cases) |

## Invariants and edge cases still to place

- `mock_product_presenter.dart` (mocks dir) must stay included at view depth —
  pinned by A13's `contains` assertion and the U2 `other`-at-view case.

## Out of scope

- Presenter classification by class shape (a presenter named e.g.
  `product_vm.dart`): layer classification is path/file-name based by design
  (spec 043 data model); renaming detection is a separate concern.
- The duplicated mock-import lines in generated `slice_di.dart` at
  presentation depth (observed during manual probing): unrelated to depth
  filtering, filed here only as an observation, not a behavior of this bug.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Depth acceptance file (slow-tagged): `dart test test/plugins/slice/slice_depth_test.dart --preset=all`
- Static analysis (full repo): `dart analyze`
- Fast suite (cloud agents): `tools/run_tests_chunked.sh`
