# TDD Verification — 1142-adaptive-layout-contract (issue #1142)

**Generated:** 2026-09-06, FRESH from this session's actual runs (FR-019
discipline — never a stale copy). Written through the `/speckit.tdd.verify`
audit: the spec's behaviors are the nine hand-written suites below (no
registered behavior artifacts for this feature at verify time), so the
guided audit path applies per
`.specify/extensions/tdd/commands/speckit.tdd.verify.md`.

## Verdict: PASS (with recorded notes)

The RED phase captured the spec's problem live (a single-layout
`StatelessWidget` `Column` generated for a feature whose Presentation
contract declares slots — plus a second defect the RED run surfaced: slot
tokens leaking in as component stand-ins), the GREEN phase landed the
AdaptiveViewState skeleton + per-platform ledger, **9/9 new tests pass**,
**192/192 tests pass across the 22 affected suites (serial, `-j 1`)**,
`dart analyze` on every changed file reports ZERO findings, and the
generated AdaptiveViewState was proven on a real Flutter host
(`flutter analyze`, Flutter 3.38.5 / Dart 3.10.4: **0 errors, 0
warnings** — the only findings are the pre-existing info-level
`subject_<id>` naming lints, issue #1035's documented tradeoff). One
environmental note recorded honestly: under `-j 4` parallelism the
fixture-heavy suites flake on `TddFixture.create`'s temp `dart pub get`
in this sandbox — reproduced on a clean `master` checkout (17 failures)
and absent serially, so the serial numbers are the ones of record.

## 1. Test-first evidence (cycle-log)

The repro suite was written and run BEFORE any implementation change
(`tdd/cycle-log.md` carries the command, exit code, and output excerpt;
full capture in `tdd/evidence/red.txt`):

| Suite | RED (pre-implementation) | GREEN (this branch) |
| --- | --- | --- |
| spec_1142_red_repro_test.dart | 1/1 failing (`does not contain 'class A001View extends StatefulWidget {'` — single-layout StatelessWidget emitted; output also rendered `Text('mobile')`, `Text('macos')` stand-ins) | replaced by spec_1142_adaptive_layout_test.dart |
| spec_1142_adaptive_layout_test.dart | — (did not exist) | 9/9 passed |

## 2. Root causes the RED phase surfaced

1. **The view step ignored the platform layout declaration** — by
   design, because none existed: `ViewCommand._renderView` composed one
   `StatelessWidget` + `Column` unconditionally, structurally different
   from the production `AdaptiveViewState` login (#1004's slots,
   #1102's per-slot audit keys). Fix: the #1142 Presentation contract
   (`adaptive_layouts` bullet) activates the adaptive renderer
   (`_renderAdaptiveView`); no declaration keeps the single-layout
   skeleton byte-for-byte (zero drift, U-1142-4).
2. **Slot tokens leaked as component stand-ins** (found IN the RED run,
   not by code review): the view's private `_presentationComponents`
   loop predated the declaration bullets, so a feature declaring
   `adaptive_layouts: mobile, macos` rendered `Text('mobile')` /
   `Text('macos')` placeholders into its own view. Fix: the view now
   delegates to `UiLedgerProjection.componentTokensOf` — the single
   derivation, which skips declaration bullets — so the skeleton and
   the ledger can never disagree on what a component IS.

## 3. The five design points, proven

1. **Spec contract** — `PlatformLayoutContract.fromContracts` parses the
   Presentation table's `adaptive_layouts` bullet (aliases
   `platform_layouts`, `platform_slots`); only Presentation rows
   contribute; an unknown slot refuses BY NAME with a `--> fix:` line
   (U-1142-9); plan refuses pre-artifact (exit 2), view refuses
   pre-write (exit 1, stub untouched — U-1142-5).
2. **AdaptiveViewState skeleton** — the generated subject carries the
   StatefulWidget + `_<View>State` with the production `_resolveSlot`
   (phone-width → narrow slot; wider surfaces branch on
   `TargetPlatform.iOS/android/macOS`, declared slots only), one
   explicit case per non-default slot plus the first-slot `_` fallback,
   per-slot keys `<snake>-slot-<slot>` (the #1102 auditor's branch
   identity), and one layout stub per declared slot (U-1142-1).
3. **Per-platform ledger coverage** — `PlatformCoverageLedger.derive`
   crosses the #1141 declared surfaces × the declared slots; a row is
   DONE iff a green prover of the surface EXERCISED that slot (the
   #1005 SkinEvent stream via `slotsFromTrace`). The proof: an
   aggregate 100% green ledger whose only prover emitted
   `slot=mobile` events leaves every macos row NOT-DONE (U-1142-6) —
   the aggregate never masks the macOS gap.
4. **TODO placeholders** — every layout stub carries
   `Text('TODO: Implement <view> <slot> layout', textAlign:
   TextAlign.center)` following the adaptive_layout_scaffold_builder
   pattern, allow-listed as generator identity in the #1141 audit
   (`_todoMarkers`); the composed scenario surfaces render in EVERY
   stub so the paired test can flip green on each slot (U-1142-2).
5. **Heatmap** — `kindCoverageHeatmap` renders the kind × slot
   `traced/total` matrix (`| text | 1/1 | 0/1 |`); plan appends the
   `# Platform Coverage Ledger` section + heatmap to `tdd/ui-ledger.md`
   and the per-slot rows to `ui-ledger.json` when slots are declared
   (U-1142-7, U-1142-8; plan-time evidence is empty ⇒ every per-slot
   row NOT-DONE — visible, never omitted).

## 4. Verification protocol (ACTUAL runs, this session)

Toolchain: Dart SDK 3.13.3 (stable) — `dart analyze` / `dart test` /
`dart format`; Flutter 3.38.5 (stable) — `flutter analyze` on a scratch
host (`/tmp/zfa_1142_proof`, `flutter create` + the three E2E-generated
subjects + a minimal slang-accessor stand-in). Kernel cache cleaned per
protocol (`rm -rf .dart_tool/test/`, `rm -f $TMPDIR/dart_test.kernel.*`).

- `dart analyze` on ALL changed Dart sources (3 modified + 3 new files):
  **No issues found!** (0 errors / 0 warnings / 0 infos)
- `dart test -j 1` over the 22 affected suites: **192/192 passed**
  (spec-1142 suite 9/9; view/audit/ledger/i18n 60/60; plan/skin/corpus/
  func/912 81/81; property + json-flag + exit-code-sweep 42/42).
- `dart format` (changed files): **0 changed** (`--set-exit-if-changed`
  exit 0).
- `flutter analyze` on the three generated AdaptiveViewState subjects:
  **0 errors, 0 warnings**; 3 info-level `non_constant_identifier_names`
  findings — one per generated `subject_<id>` function name, the
  pre-existing #1035 generator convention (identical for the pre-1142
  single-layout shape; hosts that enforce infos carry the in-file
  `// ignore_for_file` suppression, as the example app's subjects do).
  Full output: `tdd/evidence/flutter_analyze.txt`.
- **E2E on the acceptance fixture**: a scratch copy of
  `example/specs/004-login-ui` (with the #1142 declaration added to the
  Presentation contracts) driven through the real CLI
  (`dart run bin/zfa.dart tdd view A1142 --project …`):
  `layouts: mobile, macos — AdaptiveViewState with one layout stub per
  slot (issue #1142)` and both `A1142ViewMobileLayout` +
  `A1142ViewMacosLayout` emitted with per-slot keys and TODO
  placeholders; the keyed composition renders `Text(t.auth.signIn)` in
  both stubs and the #1141 audit stays clean. Generated subjects
  preserved under `tdd/evidence/`.
- Full-repo suite baseline: `test/plugins/tdd/` on clean `master` passes
  serially (1516/1516) and flakes identically to this branch under
  `-j 4` (fixture `pub get` races — environmental, recorded above).

## 5. Success criteria — PROVED vs NOT

- **SC-001** (`zfa tdd view` for a slot-declaring 004-login-ui emits
  both layout stubs): **PROVED** — E2E CLI run + U-1142-1/U-1142-2.
- **SC-002** (ledger shows coverage per platform, not just aggregate):
  **PROVED** — U-1142-6/U-1142-7/U-1142-8 (mobile-only evidence leaves
  macos NOT-DONE; heatmap names the gap).
- **SC-003** (the generated AdaptiveViewState compiles with flutter
  analyze): **PROVED on a real Flutter host** — 0 errors, 0 warnings;
  the 3 info-level naming lints are the pre-existing #1035 convention,
  recorded rather than hidden.
- **SC-004** (zero drift + no new failures): **PROVED** — U-1142-4 plus
  192/192 across every suite that touches the changed files, with the
  `master` baseline cross-checked.

Not proved (honest gaps, none blocking): the generated skeleton was
analyzed, not WIDGET-TESTED on a device (no iOS/macOS runner in this
sandbox — the #1005 slot events for the generated stubs remain the
handcraft seam's runtime obligation); the `-j 4` fixture flake is
environmental but unfixed here (out of spec scope).
