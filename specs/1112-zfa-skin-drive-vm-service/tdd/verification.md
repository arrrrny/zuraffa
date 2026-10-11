# TDD Verification — spec `1112-zfa-skin-drive-vm-service`

RED → GREEN → verify, with REAL evidence from this branch's runs.
Every count below comes from an actual `dart test` / `flutter test` /
`flutter analyze` / `zfa skin drive` invocation; nothing is inferred.
Environment: Dart 3.13.2 / Flutter 3.47.2 stable (the spec's declared
toolchain) — `dart` from the Flutter SDK, Linux sandbox.

## 1. Root cause (TDD step 1)

Read issue #1112, the parent EPIC #1015, #1099 (zuraffa_ui), #1111
(contract→ZuraffaApp), and the live tree this repo ships today:

- The pilot's driver (`drive_guest.dart`) lived in `~/zik_zak_test` on
  the pilot machine — it is NOT in this repo (grep: zero hits), and the
  repo carries ZERO synthetic-click code (`cliclick`, `CGEvent`,
  `AXUIElement`, `kAXPressAction`, `xdotool`, `osascript`: only
  doc-comment mentions of the pilot lessons in `lib/src/skin/`).
- The framework half of the seam EXISTS since #1102:
  `ZfaAnchors` + `ZfaAnchorRegistry` (`lib/src/skin/anchors.dart`), and
  the emitted kit carried a registry-based `debugTapAnchor` returning
  `Future<bool>` — no typed verdict, no element walk, no CLI, no
  per-view functions, no test bridge.
- `zfa skin` had only `kit` and `verify` subcommands; `vm_service` was
  a transitive dep only; `ViewClassSpec` had no anchor vocabulary.

## 2. RED (step 2 — reproduced before any implementation)

The 5 test files were written FIRST, against the intended APIs, on the
pristine branch (before any of this spec's lib/ code landed):

- `test/skin/tap_result_test.dart`
- `test/skin/builders/skin_kit_driver_seam_test.dart`
- `test/plugins/view/view_skin_driver_seam_test.dart`
- `test/commands/skin_drive_command_test.dart`
- `test/skin/vm_tap_driver_test.dart` (+ fixture
  `test/fixtures/vm_tap_driver/seam_app.dart`)

```text
$ dart test test/skin/tap_result_test.dart \
            test/skin/builders/skin_kit_driver_seam_test.dart \
            test/plugins/view/view_skin_driver_seam_test.dart \
            test/commands/skin_drive_command_test.dart \
            test/skin/vm_tap_driver_test.dart
00:00 +0 -5: Some tests failed.

  test/skin/tap_result_test.dart: Error when reading
    'lib/src/skin/tap_result.dart': No such file or directory
  test/skin/vm_tap_driver_test.dart: Undefined name 'VmTapDriver'.
  ... (every new module: SkinDriveCommand.exitCodeForLabel,
       buildBridge/bridgeFileName, ViewClassSpec.anchors,
       debugTapAnchorJson — nothing existed)
```

RED captured: `+0 -5` — every new module failed to LOAD because it did
not exist. Full transcript: `tdd/red-evidence.txt`.

## 3. GREEN (step 3 — implementation + passing runs)

Implementation (see `spec.md` "Design" for the landing map):

- `lib/src/skin/tap_result.dart` — the sealed `TapResult`
  (`TapFound` / `TapDisabled` / `TapNotFound` / `TapError(message)`)
  with the canonical JSON (`{"result":"found","tapped":true}` …),
  `fromJson`/`fromJsonString` round trips; exported through
  `lib/src/skin/skin_contract_kit.dart` → `lib/skin.dart`.
- `lib/src/skin/builders/skin_contract_kit_builder.dart` — the emitted
  Flutter glue upgraded: `debugTapAnchor` → `Future<TapResult>` via the
  pilot's element walk (`WidgetsBinding.instance.rootElement` +
  `visitChildElements(search)`, find the anchor by its `zfa:<id>` key /
  `ZfaButton` contract id, read `contractEnabled`/`onPressed` →
  found vs disabled, `TapNotFound`, `TapError` on walk/invoke failure,
  `kDebugMode` guard); added the synchronous
  `String debugTapAnchorJson(String)` evaluate facade +
  `debugRegisteredAnchors()` diagnostics; added `buildBridge()` →
  `test/skin/zfa_anchor_test_bridge.dart` with
  `zfaAnchorTapped(WidgetTester tester, String zfaKey)` +
  `pumpAndSettle`; `bridgeKitImport()` emits the app's `package:` URI
  for the kit import (see §4 — a relative import compiles a second kit
  library and the walk dies). `zfa skin kit` writes both files
  (skip-if-exists, `--force`).
- `lib/src/plugins/view/builders/view_class_builder.dart` +
  `view_plugin.dart` + `generator_config.dart` + `view_command.dart` +
  `make_command.dart` — `--anchor <id>` (repeatable): the view gains
  one `SkinContractRow.anchorExists` row AND one
  `Future<TapResult> debugTap<PascalAnchor>() => debugTapAnchor('zfa:<id>')`
  per declared anchor (kebab→Pascal: `log-out` → `debugTapLogOut()`).
  Without anchors the output is unchanged (byte-compat test).
- `lib/src/skin/driver/vm_tap_driver.dart` + `skin_command.dart` —
  `zfa skin drive --dart-uri --anchor --timeout --verbose`: http→ws
  URI normalization, kit-first library candidate ordering, evaluate of
  `debugTapAnchorJson`, auto-resume of a paused-at-start isolate (the
  `flutter test --start-paused` lane), bounded poll until the anchor
  answers, TapResult JSON as the FINAL stdout line, exit codes
  found 0 / disabled 1 / notFound 2 / error 3. `vm_service: ^15.3.0`
  promoted to a DIRECT dependency (pure Dart — Constitution VII holds).

GREEN runs (Dart 3.13.2, this branch) — 40 NEW tests:

```text
$ dart test test/skin/ test/commands/skin_command_test.dart \
            test/commands/skin_drive_command_test.dart \
            test/commands/make_skin_flag_test.dart \
            test/commands/make_command_test.dart \
            test/commands/make_command_xray_default_test.dart \
            test/plugins/view/
01:48 +147: All tests passed!
```

Per-suite (the 5 new files):

| suite | tests |
|---|---|
| `test/skin/tap_result_test.dart` | +9 |
| `test/skin/builders/skin_kit_driver_seam_test.dart` | +16 |
| `test/plugins/view/view_skin_driver_seam_test.dart` | +5 |
| `test/commands/skin_drive_command_test.dart` | +5 |
| `test/skin/vm_tap_driver_test.dart` (REAL vm_service) | +5 |

The pre-existing #1102 assertion on the old seam signature
(`Future<bool> debugTapAnchor`) was updated to the typed
`Future<TapResult>` — the issue supersedes it.

## 4. The emitted Flutter glue — REAL compile + runtime proof

The framework repo is pure Dart (Constitution VII), so the Flutter half
can only be proven in a real Flutter target. A scratch app
(`flutter create`, Flutter 3.47.2 / Dart 3.13.2, `zuraffa` from THIS
branch via path dependency) was wired with the kit emitted by THIS
branch's real CLI:

```text
$ dart run bin/zfa.dart skin kit --root <scratch> --route login --route deals
skin kit: wrote <scratch>/lib/src/skin/skin_contract_auditor.dart
          (routes: 2 from explicit --route flags)
          + <scratch>/test/skin/zfa_anchor_test_bridge.dart

$ flutter analyze      # No issues found!
$ flutter test         # 00:01 +8: All tests passed! (7 seam + 1 smoke)
```

The 7 seam widget tests (`tdd/seam_widget_test.dart.txt`) prove on
REAL Flutter:

1. `debugTapAnchor('zfa:signin-guest')` → `TapFound` AND the REAL
   `onPressed` ran (`guestTaps == 1`).
2. The bare id form works (`signin-guest`).
3. `debugTapAnchor('zfa:log-out')` on a `contractEnabled: false`
   anchor → `TapDisabled`, and the handler NEVER fired.
4. `debugTapAnchor('zfa:never-declared')` → `TapNotFound`.
5. `debugTapAnchorJson` returns the exact canonical bytes
   (`{"result":"found","tapped":true}` / `{"result":"disabled",…}` /
   `{"result":"notFound",…}`).
6. `zfaAnchorTapped(tester, 'zfa:signin-guest')` (the bridge) →
   `TapFound` + `pumpAndSettle` settles (the test-tree anchor can't
   reschedule itself — pilot lesson 5).
7. The anchors register into `zfaAnchorRegistry` while mounted.

The scratch-app compile check caught and fixed TWO REAL emission bugs
the pure-Dart suite could not see (the same phenomenon the 1102
verification recorded):

- `StatefulElement` → `_ZfaButtonState` needs an explicit
  `element.state is _ZfaButtonState` check + cast (template now emits
  it), and the deprecated `renderViewElement` became
  `rootElement` (flutter analyze clean on the emitted file).
- The bridge's relative kit import compiled a SECOND kit library
  (two registries, two private `_ZfaButtonState` types) — the walk
  reported "anchor key present but no ZfaButton carries it". Fixed by
  `bridgeKitImport()` emitting the app's `package:` URI; the
  `zfaAnchorTapped` test went red → green.

Receipts (`tdd/`): `emitted_kit_sample.dart.txt`,
`emitted_bridge_sample.dart.txt`, `seam_widget_test.dart.txt`,
`drive_target_test.dart.txt`.

## 5. The CLI driven LIVE — both lanes (REAL runs)

Lane 1 — live Dart VM service (pure-Dart fixture app whose library
exposes the same `debugTapAnchorJson` seam; the driver under test
connects, enumerates, evaluates):

```text
$ dart test test/skin/vm_tap_driver_test.dart
00:00 +5: All tests passed!
```

— including the genuine-flow proof: the invoked handler prints to the
target's own stdout (`TAPPED:signin-guest`), so the test asserts the
REAL callback ran, not a stub. The dead-VM case reports an honest
`TapError` (exit 3), never a crash.

Lane 2 — a LIVE widget-test runner (`flutter test --start-paused`,
flutter_tester). The driver auto-resumed the paused isolate, polled
while the test booted, then evaluated:

```text
$ flutter test --start-paused test/skin/drive_target_test.dart
The Dart VM service is listening on http://127.0.0.1:43521/<token>/
The test process has been started. Set any relevant breakpoints and
then resume the test in the debugger.

$ dart run bin/zfa.dart skin drive --dart-uri=$URI \
    --anchor=zfa:signin-guest --timeout 90 --verbose
   connecting to ws://127.0.0.1:43521/<token>/ws
   connected: 1 isolate(s)
   isolate is paused (PauseStart) — resuming
   isolate resumed and running
   isolate isolates/7073747479961171: 1039 library/libraries, 1019 seam candidate(s)
   verdict notFound — target may still be booting; polling until 90s deadline
   connecting to ws://127.0.0.1:43521/<token>/ws
   connected: 1 isolate(s)
   isolate isolates/7073747479961171: 1039 library/libraries, 1019 seam candidate(s)
zfa skin drive: anchor=zfa:signin-guest verdict=found (exit 0)
{"result":"found","tapped":true}
drive exit code: 0

=== runner log (the test's own trace) ===
00:00 +0: the drive target holds a live anchor tree
DRIVE_TARGET_READY
Shell: TAPPED:signin-guest
```

SC2 PROOF: PASS — the SAME command on a widget-test runner returns the
SAME JSON shape (`{"result":"found","tapped":true}`), and the REAL
onPressed ran inside the live widget tree (the test's own
`TAPPED:signin-guest` trace line). Full transcript:
`tdd/receipts/widget_runner_drive.txt`.

## 6. Simulate/test-lane integration + the cliclick deletion criterion

- The skin lanes' ONLY tap paths are the NEW seam: the emitted
  `zfaAnchorTapped` bridge for widget-test behaviors (`zfa tdd
  run-skin` / `zfa simulate` skin behaviors are widget-test driven)
  and `zfa skin drive` for the live-app lane. Both call the same
  `debugTapAnchor` element walk — one verdict vocabulary, one JSON
  shape, no platform flakiness.
- Grep evidence (the deletion criterion): the repo contains ZERO
  synthetic-click code. `cliclick|CGEvent|AXUIElement|kAXPressAction|
  drive_guest|xdotool|osascript` across `lib/ test/ bin/ tool/
  scripts/ apps/ examples/ doc/ docs/ specs/` matches only
  doc-comment mentions of the pilot lessons. The pilot's
  `drive_guest.dart` never lived in this repo (`~/zik_zak_test` on the
  pilot machine) — nothing to delete, and nothing was added in its
  place except the seam.

## 7. /speckit.tdd.verify — the deterministic gate

Not run as a mutation gate: this repo-level framework spec carries no
`tdd/artifacts.json` behavior registry (the same honest state spec
1005/1102 recorded — the mutation audit applies to registry-driven
target features). The REAL red→green evidence for THIS spec's
behaviors is §2–§5. The gate would report `not_assessed`, and we
report that honestly instead of fabricating a score.

## 8. Full-suite verification

```text
$ dart analyze
135 issues found.      # pristine HEAD (git stash): 143 issues —
                        # the branch introduces ZERO new analyzer
                        # findings (counts differ because the branch's
                        # analyze context resolves differently; every
                        # finding in changed files was checked:
                        # the 1 info in make_command.dart pre-exists
                        # on HEAD, verified via git stash + analyze)

$ dart format .
Formatted 2421 files (0 changed)  # zero remaining formatting diffs
$ git diff --stat                 # no formatting deltas
```

Affected-lane test totals (§3): 147 passing, 0 failing. The full
chunked suite (`tools/run_tests_chunked.sh`) was not re-run; the
affected lanes (skin, commands, view, make) are 100% green and the
analyzer is at-or-better than the pristine baseline.

## 9. Success criteria — proved vs not

- PROVED: `debugTapAnchor` is a kDebugMode-only
  `Future<TapResult>` using the pilot's element walk, with the typed
  found/disabled/notFound/error(String) verdicts (§3, §4).
- PROVED: `zfa make --skin --anchor …` emits the per-view
  `debugTap<PascalAnchor>()` seam + `anchorExists` rows; byte-compat
  without anchors (§3).
- PROVED: `zfa skin drive` wraps `package:vm_service`, evaluates the
  seam, prints the TapResult JSON as the final stdout line, honest
  exit codes (§3, §5).
- PROVED: same JSON shape on a widget-test runner — LIVE
  flutter_tester drive, exit 0, `{"result":"found","tapped":true}`,
  real handler traced in the runner log (§5).
- PROVED on macOS coordinates: NOT EXERCISED — this sandbox cannot run
  `flutter run -d macos`; the identical code path (same evaluate, same
  JSON, same CLI) is proven on live Dart-VM and flutter_tester targets
  on Linux (§4–§5). The macOS synthetic-click wall is exactly what the
  seam bypasses — the driver never touches the OS event system.
- PROVED: skin behaviors drive through `debugTapAnchor` exclusively;
  zero synthetic-click code in the repo (§6).
- PROVED: the widget test bridge `zfaAnchorTapped(tester, zfaKey)` —
  emitted as the target project's `package:zuraffa_test` surface —
  with the safe `pumpAndSettle` (§4).
- NOT ASSESSED: mutation score (no behavior registry — §7).

## 10. Reproduction

```bash
dart pub get
dart analyze                                   # 135 == or better than master
dart test test/skin/ test/commands/ test/plugins/view/

# the emitted-Flutter proof (Flutter 3.47.2):
flutter create scratch_1112 && cd scratch_1112
dart pub add zuraffa --path=<this-branch>
dart run zuraffa:zfa skin kit --root . --route login --route deals
flutter analyze && flutter test

# the LIVE widget-test-runner drive:
flutter test --start-paused test/skin/drive_target_test.dart &  # (restore from tdd/)
dart run zuraffa:zfa skin drive --dart-uri=<vm-uri> --anchor=zfa:signin-guest
# → {"result":"found","tapped":true}
```

## 11. Addendum — follow-up commit: `zfa simulate skin` (the literal verb) + independent re-verification

A follow-up session independently re-verified this branch's lanes in a
fresh sandbox (Dart 3.13.3 stable, no Flutter SDK) and closed the one
remaining literal-reading gap of spec item 4 ("zfa simulate
integration. Skin behaviors driven through debugTapAnchor"): the
`zfa simulate` surface now carries the dedicated skin-behavior verb.

**Added (follow-up commit):**

- `zfa simulate skin --dart-uri=<uri> --behaviors zfa:signin-guest,…`
  (`SimulateSkinCommand`, parser-only registration per the bug #856
  lesson): drives every behavior through the SAME [SkinDriveFn] seam
  (`VmTapDriver.drive` in production — one verdict vocabulary, one
  JSON shape), prints one JSON verdict line per behavior plus a
  summary line, and exits with the most severe verdict on the
  [SkinDriveExitCode] ladder (found 0 < disabled 1 < notFound 2 <
  error 3).
- `test/commands/simulate_skin_command_test.dart` — 5 tests (order +
  JSON lines, severity ladder, error verdict, usage verdict, legacy
  flag-mode regression guard).

**Independent re-verification (REAL runs, fresh sandbox, this branch
+ follow-up commit):**

```text
$ dart test test/skin/
114 passed, 0 failed   (incl. the 5 REAL vm_service E2E tests)

$ dart test test/commands/skin_command_test.dart \
            test/commands/skin_drive_command_test.dart \
            test/commands/make_skin_flag_test.dart
56 passed, 0 failed

$ dart test test/commands/ test/skin/
410 passed, 0 failed   (whole CLI surface, exit-protocol golden included;
                        the only excluded lane is test/plugins/view/
                        view_compile_test.dart — environment-blocked
                        here: no Flutter SDK, same pre-existing failure)

$ dart analyze lib/src/commands/simulate_command.dart \
               test/commands/simulate_skin_command_test.dart
No issues found!
```

**LIVE CLI proof (real VM service, the integrated surface):**

```text
subject: dart --enable-vm-service=28195 test/fixtures/vm_tap_driver/seam_app.dart

$ zfa skin drive --dart-uri=http://127.0.0.1:28195/ --anchor=zfa:signin-guest
zfa skin drive: anchor=zfa:signin-guest verdict=found (exit 0)
{"result":"found","tapped":true}
exit=0

$ zfa skin drive --dart-uri=… --anchor=zfa:signin-ghost
zfa skin drive: anchor=zfa:signin-ghost verdict=notFound (exit 2)
{"result":"notFound","tapped":false}

$ zfa simulate skin --dart-uri=http://127.0.0.1:28195/ \
    --behaviors zfa:signin-guest,zfa:signin-logOut
{"behavior":"zfa:signin-guest","result":"found","tapped":true}
{"behavior":"zfa:signin-logOut","result":"notFound","tapped":false}
simulate skin: behaviors=2 found=1 disabled=0 notFound=1 error=0
exit=2

subject stdout: TAPPED:signin-guest (×2 — the REAL onPressed ran in the
live VM once per verb: drive + simulate skin)
```

Provenance note: §1–§10 are the original branch session's evidence
(Dart 3.13.2 / Flutter 3.47.2). This §11 addendum is a second, independent
session's verification of the same branch plus the `zfa simulate skin`
follow-up — every count and transcript above it is from an actual run.
