# Cycle Log: slice-depth-view-includes-presenter (#597)

Append only. Newest last. Every `red` block below is real output captured in
this session (2026-09-01) from the commands shown; nothing is reconstructed.

## Baseline

- suite: `dart test test/plugins/slice/slice_depth_test.dart --preset=all`
  -> `00:00 +4: All tests passed!` (A13/A14/A15 + invalid-depth)
- commit: `11de4bfc`
- recorded: cycle 0, before any change
- finding: the bug record's failing state does NOT reproduce at HEAD — A13 is
  green and a manual `zfa slice cut product_feature --entry product --depth
  view` in a fixture copy excludes `product_presenter.dart` (sandbox: only
  view/controller/state + widgets + generated mocks + slice_di). The
  remediation the assessment proposes is already in HEAD (the
  `interfaceIncluded` guard in `cut_slice_capability.dart`, walker layer
  gates, inline-abstract-interface mocks), merged with PR #595 at
  2026-08-30 07:03 UTC, ~30 min before the issue was filed (07:37 UTC). The
  issue record is stale relative to the merge.
- residual gap found at HEAD (real probe, `classifyLayer`):
  `lib/src/presentation/presenters/product_presenter.dart -> layer=presentation_shared includedAtView=true`
  — a presenter outside `pages/` leaks into `--depth view` exactly as the
  issue's root-cause hypothesis describes ("view as including presentation
  wholesale"). Cycles below fix that.

## Cycle 1: U1 — a presenter anywhere under presentation/ is the presenter layer

- test: `test/plugins/slice/models/file_graph_test.dart::classifyLayer a
  presenter anywhere under presentation/ is the presenter layer (597)` (new)
- red: `dart test test/plugins/slice/models/file_graph_test.dart`
  -> `Expected: 'presenter' / Actual: 'presentation_shared' ... Differ at offset 7`
  (8 passed, 1 failed — the other 8 classification/tier assertions held)
- green: `lib/src/plugins/slice/models/file_graph.dart` — `classifyLayer`
  detects presenters by file name anywhere under `lib/src/presentation/`
  (not only under `pages/`); re-run -> `00:00 +9: All tests passed!`; probe
  re-run -> `lib/src/presentation/presenters/product_presenter.dart ->
  layer=presenter includedAtView=false` while widgets and the mocks dir stay
  included at view depth
- cross-checks (all real, same session):
  `dart test test/plugins/slice/slice_depth_test.dart
  test/plugins/slice/models/file_graph_test.dart --preset=all`
  -> `+14: All tests passed!` (A13, A13b, A14, A15, invalid-depth, U1, U2)
- refactor: none required — the fix is a 3-line tightening
- commit: (lands with this fix commit per repo convention: red committed
  alongside the implementation that turns it green)

## Cycle 2: A2 — presentation tier guard-rail (characterization)

- test: `test/plugins/slice/slice_depth_test.dart::A13b (597): depth
  presentation — presenter in, domain still out` (new)
- red: none — this tier had NO test coverage before (verified: no other test
  drives `--depth presentation`); the test is a characterization pinning
  behavior the assessment requires confirming. It passed on first run:
  `+10: A13b (597): depth presentation — presenter in, domain still out`
  within the `+14: All tests passed!` file run.
- manual corroboration before writing it (real cut):
  `zfa slice cut pres_tier --entry product --depth presentation` ->
  `Cut slice "pres_tier": 5 project files, 4 boundary interfaces`;
  sandbox pages/product contains `product_presenter.dart`; no domain files;
  `slice_di.dart` registers MockGetProductUseCase/MockProduct etc.
- refactor: none
- commit: (lands with this fix commit)

## Deliberate mutants (no mutation tool in the profile)

- mutant 1: removed `if (base.contains('presenter')) return 'presenter';`
  from `classifyLayer` -> `dart test test/plugins/slice/models/
  file_graph_test.dart --plain-name "presenter anywhere"` -> 1 failed
  (Expected 'presenter' / Actual 'presentation_shared'). Caught.
- mutant 2: re-introduced the #597 regression by adding `'presenter'` to the
  view tier in `layerAllowedAtDepth` -> `dart test
  test/plugins/slice/slice_depth_test.dart --plain-name "A13" --preset=all`
  -> A13 (T099) failed. Caught — the committed acceptance test still guards
  the original bug.
- both mutants restored exactly (`cp` of the pre-mutant file);
  post-restore `dart test test/plugins/slice/models/file_graph_test.dart`
  -> `00:00 +9: All tests passed!`

## Notes and deviations

- The task brief expected cycle 0 to be a red A13. It is not: the merged
  tree already contains the fix. Per the brief's own rule ("Do not claim a
  step passed that you did not run"), the non-repro is recorded here as the
  baseline finding, and the red→green evidence this branch contributes is
  U1 (the residual classification gap in the same depth filter).
- Chunked fast-suite run: the runner's per-chunk `dart test` consumed the
  chunk-list stdin at `test/plugins/mcp`, so chunks after it were executed
  manually with stdin redirected (all green; see verification.md).
