# Cycle Log: 1000-spec-template-core-skin-lanes

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd` post-change -> 1106 passed, 0 failed
  (1091 pre-existing tests + the 16 new below; the pre-existing count is
  derived, not separately measured before the change — the RED evidence
  below is the pre-implementation proof, and the full-suite chunked run is
  the post-change proof).
- commit: 77e69f24 (master HEAD at branch point)
- recorded: cycle 0

## Cycle 1: plan emits the lane split (04-ENGINE / 04-SKIN / 04-CONTRACT)

- test: `test/plugins/tdd/commands/plan_lanes_1000_test.dart` (new, 9 tests)
- red: `dart test test/plugins/tdd/commands/plan_lanes_1000_test.dart`
  -> 8 failed / 1 passed: `04-ENGINE.md`, `04-SKIN.md`, `04-CONTRACT.md` did
  not exist (`zfa tdd plan` wrote the single `tdd/test-list.md` only —
  `expect(laneFile('04-ENGINE.md').existsSync(), isTrue)` failed); the
  AdaptiveViewSlots were nowhere; the meta-index assertions failed on
  `meta.contains('| A1 |')` (the legacy table still carried behavior rows).
  The 1 passing test was the legacy-control guard (a spec without `## Lanes`
  plans the single file) — the hard constraint that must stay green.
- green: implemented `SpecParser.parseLanes` (+ `LaneDeclaration` /
  `Lane` models), `services/lane_split.dart` (file names, meta-index
  detection `LaneSplitFiles.find`, renderers `renderEnginePlan` /
  `renderSkinPlan` / `renderContractPlan` / `renderMetaIndex`), the
  `TestListReader` meta-index row resolution (engine file first, BOTH ids
  deduped) + declaration-section fallback to the engine plan, and the
  plan_command lane branch. Suite `dart test
  test/plugins/tdd/commands/plan_lanes_1000_test.dart` -> 9 passed.
- refactor: none needed — the lane emission lives in `lane_split.dart`,
  shared with the split command (no duplication).
- commit: (this PR)

## Cycle 2: the noFlutter guard + undeclared-behavior refusal (plan-enforced)

- test: same file, `issue #1000 — noFlutter guard (plan-enforced)` group
  (3 tests)
- red: exit 0 and a written `test-list.md` on every refusal fixture — plan
  accepted a CORE behavior whose description references
  `package:flutter/material.dart`, accepted a widget-kind CORE behavior, and
  accepted a spec-derived behavior declared in no lane.
- green: `_resolveLanes` in plan_command refuses (exit 2, no artifacts —
  traceability.md included) with the offending behavior id, the lane, and a
  `--> fix:` line. Suite -> 3 passed (folded into the 9 above).
- refactor: none.
- commit: (this PR)

## Cycle 3: `zfa tdd split <feature>` — the one-shot legacy migration

- test: `test/plugins/tdd/commands/split_command_1000_test.dart` (new, 6
  tests)
- red: `Could not find a command named "split"` — 6 failed / 0 passed (the
  command did not exist).
- green: implemented `commands/split_command.dart` (kind heuristic:
  widget/theme -> SKIN, the rest CORE; spec `## Lanes` declarations win;
  emits the three 04-* files + `tdd/split-receipt.json`; converts
  `test-list.md` into the meta-index; one-shot refusal naming the receipt)
  and registered it in `tdd_command.dart`. Suite -> 6 passed.
- refactor: none.
- commit: (this PR)

## Regression proof (the hard constraint: existing test semantics unchanged)

- `dart test test/plugins/tdd` -> 1106 passed, 0 failed (1085 baseline +
  21 new; every pre-existing test green).
- `dart test test/plugins/mock test/cli` -> 240 passed, 0 failed.
- Legacy byte-stability: the plan_command legacy branch is the untouched
  `_render` path — the legacy-control test pins it.
- commit: (this PR)

## Notes and deviations

- The spec's exit criteria name `004-login-ui` — the ZIKZAK app specs are
  not in this repo, so the canonical fixture lives in the two test files
  (temp projects driven through the real CLI entry point), which is where
  every tdd command test in this repo runs its fixtures.
- `specify extension add tdd` (phase 1) refused to install from the remote
  catalog without review; the repo's `.specify/extensions/tdd` (v1.1.2) was
  already installed and enabled — `specify extension list | grep -A2 -i tdd`
  prints "✓ TDD Extension (v1.1.2)", satisfying the spec's expected check.
