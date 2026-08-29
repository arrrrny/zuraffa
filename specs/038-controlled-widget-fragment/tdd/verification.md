# TDD Verification: ControlledWidget with FragmentBuilder for Granular Rebuilds

Audit report for `/speckit.tdd.verify` — spec 038, branch `038-controlled-widget-fragment`.

**Verdict: PASS.** Every acceptance criterion is backed by a green acceptance test, every behavior on the test list is `DONE` with a named test, red evidence exists for each TDD cycle (compile-red or assertion-red as appropriate), and deliberate-mutant sampling confirms the suite constrains the implementation (4 of 5 mutants killed; the survivor is documented with its rationale below).

## 1. Suite status

| Command | Result |
|---------|--------|
| `dart test test/state` (feature scope) | **99 passed, 0 failed** (baseline at `4c1c2641`: 68 passed — +31 new, 0 regressions) |
| `dart test test/state/widgets` | 31 passed, 0 failed |
| `dart test test/core test/plugins/route` | 607 passed, 1 skipped, 0 failed |
| `dart test test/plugins/state` | 2 passed, 0 failed |
| `dart test` (fast tier, whole repo) | recorded below in §5 before the PR |
| `dart analyze lib/ test/state/widgets/` | 0 errors, 0 new warnings (1 pre-existing `unused_element` warning in `route_builder.dart`, present on master) |

Suite baseline at planning time was green (68/68 in scope), so no red predated the feature.

## 2. Acceptance criteria — proven or not

| SC | Claim | Status | Evidence |
|----|-------|--------|----------|
| SC-001 | Typed controller + lifecycle + slice rebuilds from a scaffold, no manual wiring | **PROVEN** | `sc_001_typed_controller_lifecycle_test.dart` — full stack (DualLayerPresenter + DomainState late-final slice + ViewState signal): mount fires `onInit` once (typed access, no casts), slice data arrives async and rebuilds the fragment automatically, host unmount cancels everything. The only developer calls in the test are `mount()`/`unmount()`. |
| SC-002 | Slice change rebuilds only its bound subtree | **PROVEN** | `sc_002_slice_isolated_rebuild_test.dart` — rebuild counting through the real presenter API: sales refresh → sales fragment +1, stock fragment +0, UI signal builder +0, `host.buildCount` stays 1. Symmetric for stock. |
| SC-003 | Generated views compile + use the v6 pattern | **PROVEN** | `sc_003_generated_view_compiles_test.dart` — `generateView(..., pureDart: true)` output is `dart analyze`d (exit 0, no errors) inside a temp package with fixture presenter/domain/view-state; pattern assertions for `ControlledWidget`/`FragmentBuilder`/`SignalBuilder`. The default (Flutter) emission is byte-identical to the pre-feature golden. |
| SC-004 | Pre-v6 views compile and run unchanged | **PROVEN** | (a) `sc_004_pre_v6_compat_test.dart` — combined-state full-rebuild view keeps exact pre-v6 semantics while a v6 view mounts alongside; (b) all pre-existing pre-v6 suites (`slice_presenter_test`, `dual_layer_presenter_test`, `signal_slice_test`, `state_generator_test`, `golden_test`, `tracks_2_3_2_4_golden_test`, `v6_cli_generation_test`, migration tests) re-ran **unmodified** and green. |

## 3. Behavior coverage

All 26 unit behaviors (U1..U26) and 4 acceptance behaviors (A1..A4) are `DONE` with named tests in `tdd/test-list.md`. Red evidence per cycle is in `tdd/cycle-log.md`: cycles 1, 2, 5, 6 were compile-red (types/parameters did not exist); cycles 3, 7 were assertion-red; cycle 4's edge-case tests were born green (guards shipped with the cycle-3 state machine) and are justified by mutation results instead.

FR traceability: FR-001 (U1/U3/U6/U7), FR-002 (U8/U9/U13), FR-003 (U10..U14), FR-004 (U20..U22), FR-005 (U23/U25 + generatePresenter domain override), FR-006 (U24 + §2 SC-004), FR-007 (U2/U6), FR-008 (U4, U12, U15..U19, U21/U22). All seven spec edge cases are covered by at least one named test.

## 4. Mutation sampling (no mutation tool wired — deliberate mutants per profile)

| Mutant | Expected kill | Result |
|--------|---------------|--------|
| M1 `_isEmptyValue => false` | U12 | **Killed** (+0 -1) |
| M2 `recordRebuild` drops the counter | U16 | **Killed** (+0 -1) |
| M3 `_onSliceChange` `isAttached` guard removed | U17 | **Survived** — see rationale |
| M4 disposed-at-attach guard disabled | U18b | **Killed** (+0 -1) |
| M5 SignalBuilder disposed-fallback removed | U21 | **Killed** (+0 -1) |

**M3 rationale (recorded, not hidden):** the observable "detached fragment ignores emissions" behavior is enforced by subscription cancellation — `detach()` cancels the slice subscription, so the emission never reaches the fragment. The `isAttached` guard is defense-in-depth against a mid-notification detach race (a listener that detaches the fragment while `Signal._notify` is iterating its copied listener set). That race cannot be triggered deterministically through the public API because `Signal` listener iteration order (identity `HashSet`) is unspecified. The guard is retained with this recorded justification; the rubric's "tests constrain behavior" bar is met by the four killed mutants plus U17's cancellation-path assertion.

## 5. Whole-repo fast tier

Full `dart test` (fast tier, `slow` tags excluded per `dart_test.yaml`), executed
directory-by-directory (a single invocation exceeds CI session timeouts):

- **1,844 passed, 1 skipped, 0 failed** across every default-suite directory:
  state 99, core+plugins/route 607 (+1 skip), plugins/state 2, cli 125,
  commands 211, dda 35, domain 18, utils 72, config 10, graphql 128,
  migration 20, logging 6, i18n 11, session 20, app_update 6, biometrics 7,
  clipboard 6, device 6, share 5, secure_storage 11, scripts 1, regression 62,
  plugins: api 30, app_shell 71, datasource 5, di 6, gym 15, mcp 77
  (4 fast files + stdio + SSE server files), method_append 6, module 2,
  provider 4, repository 7, service 8, shadcn 2, sqlite 8, strategy 26,
  sync 31, usecase 17, xray 16, mock 37, toggle 3, test_builder 5.
- **1 pre-existing hang**: `test/plugins/mcp/mcp_server_plugin_test.dart` run
  as a full file hangs (SSE-server lifecycle across tests in this sandbox).
  Verified **identical on master** via a clean worktree — individual tests in
  the file pass (including `autoStartSsePort` alone). Not caused by this
  feature; flagged, not fixed.
- `test/integration`, `test/property`, `test/benchmark` are entirely
  slow-tagged — excluded from the default suite by `dart_test.yaml` (no fast
  tests there; "No tests match the requested tag selectors").
- `dart analyze` full repo: same 23 pre-existing errors confined to
  `examples/mcp_demo` and `zikzak_session` (missing git submodule content —
  both predate this branch and reproduce on master), 108 total issues at
  baseline vs. no new issues introduced here.

## 6. Honest gaps and flagged pre-existing issues

1. **`generatePresenter` emits `SlicePresenter()` — an abstract class.** The emitted presenter cannot compile as-is. Pre-existing (Flutter-mode output was never compile-checked in this pure-Dart repo); out of scope for spec 038 (FR-005 is about views). Flagged for the generator's own spec. The sc_003 fixture works around it with a concrete subclass; this feature's `generatePresenter` change (covariant `domain` getter) does not depend on the workaround.
2. **The Flutter-side `ControlledWidget`/`FragmentBuilder`/`SignalBuilder` widgets live in the separate `zuraffa_flutter` package.** This feature delivers the pure-Dart core contracts those widgets will implement (spec assumption: "Code generation templates are updated separately" boundary holds; the barrel export slots the spec anticipated are now real).
3. **`ControlledWidgetDetector`** (v5 migration info hint) flags `extends ControlledWidget` in user projects as legacy. v6 user apps extend the `zuraffa_flutter` wrapper, not the core contract, so no new false positive is introduced by this feature; detector refinement is out of scope (no FR).
4. **SC-001's "< 5 minutes"** is a developer-experience claim; the test proves the *no manual wiring* half mechanically. The wall-clock half rests on the scaffold being generated (proven in sc_003) and the API surface being mount/attach only (proven in sc_001).

## 7. Stack profile corrections

`.specify/memory/tdd-profile.md` documents the single-test filter as `dart test <file> -P "<name>"`. `-P` is the **preset** flag; the name filter is `--plain-name` (or `-N`). All red/green evidence in the cycle log was produced with `--plain-name`. The profile should be corrected in a follow-up chore (not this spec's scope).
