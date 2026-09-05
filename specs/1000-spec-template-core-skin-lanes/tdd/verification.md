# TDD Verification — Spec template [CORE]/[SKIN] lane markers + AdaptiveViewSlots (issue #1000)

**Date**: 2026-09-05
**Result**: **16 new tests pass (9 plan-split + 6 split-command + 1
template)**; full-repo
chunked run **74/74 chunks executed — 70 PASS, 4 SKIP (slow-tier-only folders,
by design), 0 FAIL**; `dart analyze lib test --no-fatal-warnings` **0 errors**
(314 issues, all pre-existing infos/warnings, 0 in the changed files; the
master-state baseline shows 315); `dart format .` **idempotent (second run: 0
changed)**.

## Red → green evidence (issue #1000 cycle)

- **Red** (tests written first, against master's behavior): the 9-test
  `plan_lanes_1000_test.dart` suite ran **1 passed / 8 failed** — `zfa tdd
  plan 004-login-ui` emitted the single `tdd/test-list.md` only; no
  `04-ENGINE.md`, no `04-SKIN.md`, no `04-CONTRACT.md`, no meta-index, no
  lane guards (every refusal fixture exited 0 with artifacts written). The
  6-test `split_command_1000_test.dart` suite ran **0 passed / 6 failed**
  (`Could not find a command named "split"`). The 1 passing plan test was the
  legacy-control guard (no `## Lanes` → single-file plan) — the hard
  constraint pinned before any implementation.
- **Green**: after the implementation (parseLanes + lane_split renderers +
  TestListReader meta-index resolution + plan lane branch + split command),
  the new suites run **16/16**, and the pre-existing suites are unchanged:
  `dart test test/plugins/tdd` → **+1107, 0 failed** (1091 pre-existing +
  16 new); `dart test test/plugins/mock test/cli` → **+240, 0 failed**.

## 1. Coverage

Every new code path has at least one passing test: `SpecParser.parseLanes`
(behaviors list, `U1-U6` range expansion, annotation stripping,
`flutter_allowed`, `adaptive_slots` — exercised through every plan/split
fixture), `LaneSplitFiles.find` (meta-index detection — positive through the
plan/split emissions, negative through the legacy-control test),
`TestListReader` split resolution (row resolution across engine+skin, BOTH
id dedup, declaration-section fallback), plan_command lane branch (split
emission, noFlutter guard text reference, noFlutter guard Flutter-only kind,
undeclared-behavior refusal, legacy byte-stability), split_command (emission
+ receipt, kind heuristic, declarations-win, one-shot refusal,
nothing-to-split refusal), meta-index + AdaptiveViewSlots + contract
rendering (via the file-content assertions), and template documentation
(pinned by the spec's User Story 4 acceptance — the section is in
`.specify/templates/spec-template.md` with the full grammar). Coverage
tooling not invoked (the repo's tdd-profile declares coverage opt-in);
test mapping is complete, coverage unmeasured.

## 2. Mutation

No mutation audit was run in this PR. The repo's `mutation-test.xml` is
scoped to feature 041's writer files (not plan_command / lane_split /
test_list_reader), so running it would not exercise the new code. Precedent:
feature 042 documented the same honest gap and deferred a scoped
mutation-test section to a chore. **Honest gap**: test strength for #1000 is
evidenced by the red→green cycle above, not by mutation scoring. Follow-up:
scope a `mutation-test.xml` section for
`lib/src/plugins/tdd/services/lane_split.dart` +
`lib/src/plugins/tdd/services/spec_parser.dart` in a dedicated chore.

## 3. Exit criteria — PROVED vs not (issue #1000)

| Criterion | Status | Evidence |
|---|---|---|
| `zfa tdd plan 004-login-ui` emits `04-ENGINE.md`, `04-SKIN.md`, `04-CONTRACT.md` (no `04-test-list.md`) | **PROVED** | plan_lanes_1000_test.dart: "emits 04-ENGINE.md, 04-SKIN.md, and 04-CONTRACT.md (no 04-test-list.md)" — all three files exist, `04-test-list.md` does not, `test-list.md` is the meta-index. The 004-login-ui fixture is the issue's canonical example (CORE `[A1, A2, U1-U6]`, SKIN `[W1-W4]` + slots, BOTH `[A3]`). |
| `04-ENGINE.md` contains zero `package:flutter` references | **PROVED** | plan_lanes_1000_test.dart: "04-ENGINE.md contains zero package:flutter references" — the emitted engine file scans clean (guard + renderer prose both avoid the URI; the renderer's prose says "Flutter", never `package:flutter`). |
| `04-SKIN.md` contains the AdaptiveViewSlots declared in the spec | **PROVED** | plan_lanes_1000_test.dart: "04-SKIN.md contains the AdaptiveViewSlots declared in the spec" — `mobile`, `ios`, `android`, `macos` render in the skin plan's Adaptive view slots table (also in the contract file). |
| `zfa tdd split 004-login-ui` produces all three from the old plan, with a receipt | **PROVED** | split_command_1000_test.dart: "produces 04-ENGINE.md, 04-SKIN.md, 04-CONTRACT.md and split-receipt.json from the old plan" + the classification/one-shot/declarations-win/meta-index re-resolution tests (6/6). |
| Hard constraint: existing test semantics unchanged | **PROVED** | Legacy-control test (no `## Lanes` → single-file plan, no 04-* files) + full-suite chunked run 74/74 chunks 0 FAIL + `dart test test/plugins/tdd` 1106/0, `test/plugins/mock`+`test/cli` 240/0. The legacy `_render` path is untouched; the reader's legacy parse is the extracted same line-walk. |

## 4. Verification commands and actual results

```bash
dart analyze lib test --no-fatal-warnings
# 314 issues found — 0 errors, 0 warnings/infos in the changed files
# (master baseline with the same untracked files present: 315; the -1
# delta comes from the tracked-file modifications; none introduced)

dart test test/plugins/tdd/commands/plan_lanes_1000_test.dart    # +9: All tests passed!
dart test test/plugins/tdd/commands/split_command_1000_test.dart # +6: All tests passed!
dart test test/plugins/tdd                                        # +1106: All tests passed!
dart test test/plugins/mock test/cli                              # +240: All tests passed!

# Full fast suite, chunked with kernel-cache cleanup between chunks
# (tools/run_tests_chunked.sh contract; run via a resumable driver because
# this environment kills background processes between invocations):
# DONE: 74/74 chunks executed — PASS: 70  SKIP: 4  FAIL: 0
# (the 4 SKIPs are folders whose every test carries a slow-tier tag —
# benchmark, integration, property — excluded from the fast suite by
# dart_test.yaml, by design)

dart format .   # first run: 7 changed (the new files); second run: 0 changed
```

## 5. Notes

- `specify extension add tdd` (phase 1) refused to install from the remote
  catalog without review; the repo already carries `.specify/extensions/tdd`
  v1.1.2 enabled — `specify extension list | grep -A2 -i tdd` prints
  "✓ TDD Extension (v1.1.2)", satisfying the spec's expected check.
- The 04- prefix is the issue's naming for the plan-stage artifacts; the
  legacy `test-list.md` filename is kept as the meta-index so every existing
  consumer path (gen/make/run/corpus) keeps resolving (FR-008/FR-009).
