# TDD Verification — spec `1102-runtime-skin-contract-auditor`

RED → GREEN → verify, with REAL evidence from this branch's runs.
Every count below comes from an actual `dart test` / `flutter test` /
`flutter analyze` / `zfa tdd verify` invocation; nothing is inferred.
Environment: Dart SDK 3.13.3 (stable) for the framework repo; the
emitted-Flutter verification ran on Flutter 3.47.2 stable /
Dart 3.13.2 (the spec's declared toolchain) with `zuraffa_flutter`
6.1.0 and `go_router` 17.5.0 from pub, `zuraffa` from this branch via
a path override.

## 1. Root cause (TDD step 1)

Read issue #1102, the 006-login-skin pilot description (kit shape,
the four demo receipts, the 8 design findings), and the live tree
this repo ships today:

- No `SkinContractKit` exists anywhere: no `TreeFacts`, no
  `SkinContractRow`, no route contract table, no audit bus, no
  scheduler, no typed anchor registry — nothing for a view or app
  shell to mount. The skin enforcement tiers that DO exist are the
  static/source tier (`zfa tdd run-skin` conformance mode, spec
  1005: SkinEvent stream + `_XRaySkinHandEdit` scan + skin receipt)
  and the CI tier (paired widget tests). Nothing checks the cake in
  the oven.
- `ViewClassBuilder` emits the `Widget get view` seam (the exact
  overridable skin seam, pilot lesson 2) with no auditor wrap, and
  no `--skin` flag exists anywhere in the view generation surface.
- `AppShellBuilder.buildMyApp`/`buildAppRouter` emit
  `MaterialApp.router` + a bare `GoRouter` — no `NavigatorObserver`,
  no violation banner chrome, no `--skin-audit` flag.
- The generated DI is not idempotent: registrations are bare
  `getIt.register*(...)` calls (verified across the 11 emission
  sites in `di_plugin.dart`), `setupDependencies(getIt)` twice
  throws, and no `resetDependencies` exists (grep: zero hits in
  `lib/`).
- No typed anchor protocol, no `debugTapAnchor`, no `zfa skin`
  command surface (grep: zero hits).

## 2. RED (step 2 — reproduced before any implementation)

The 13 test files were written FIRST, on the pristine clone (master
@ `512a8189`, before any of this spec's code landed), and failed to
LOAD — the modules did not exist:

```text
$ dart test test/skin/ test/commands/skin_command_test.dart \
            test/plugins/view/view_skin_audit_wrap_test.dart \
            test/plugins/app_shell/app_shell_skin_audit_test.dart \
            test/plugins/di/di_idempotent_test.dart
00:00 +0 -13: Some tests failed.

  test/skin/tree_facts_test.dart: Error when reading
    'lib/src/skin/tree_facts.dart': No such file or directory
  test/skin/skin_violation_test.dart: Error when reading
    'lib/src/skin/skin_violation.dart': No such file or directory
  ... (every new module: skin_contract_row, route_contract_table,
       skin_audit_controller, skin_audit_scheduler, anchors,
       skin.dart barrel, skin_contract_kit_builder, skin_command)
  test/plugins/view/view_skin_audit_wrap_test.dart:
    No named parameter with the name 'withSkinAudit'
  test/plugins/app_shell/app_shell_skin_audit_test.dart:
    No named parameter with the name 'skinAudit'
  test/plugins/di/di_idempotent_test.dart:
    No named parameter with the name 'registeredTypes'
```

RED captured (2026-09-05T07:42:19Z): `+0 -13`. Full failure
transcript: `tdd/red-evidence.txt`.

## 3. GREEN (step 3 — implementation + passing runs)

Implementation (see `spec.md` "Design" — the purity split):

- `lib/src/skin/` — the pure SkinContractKit core:
  `tree_facts.dart` (immutable snapshot + `SkinTargetPlatform`),
  `skin_violation.dart`, `skin_contract_row.dart` (`textRenders` /
  `anchorExists` / `progressIndicator` helpers with platform
  gating), `route_contract_table.dart` (root `/` conforms by
  construction — lesson 3), `skin_audit_controller.dart` (bus core
  with change detection + bounded history),
  `skin_audit_scheduler.dart` (markDirty/consumeDirty —
  subscribe-don't-poll, lesson 5), `anchors.dart`
  (`ZfaAnchors` + `ZfaAnchorRegistry` — lessons 6/7), barrel
  `skin_contract_kit.dart`, public library `lib/skin.dart`.
- `lib/src/skin/builders/skin_contract_kit_builder.dart` — the
  emitted Flutter glue (one self-contained file per target project):
  `inspectTree(Element)` (texts, `zfa:` keys, progress indicators,
  platform from `Theme.of`), `SkinContractAuditor` (audits on the
  post frame ONLY when the scheduler consumed a dirty mark;
  subscribe channels: dependencies, row updates, `Listenable`
  notifications, hot-reload `reassemble()`), `SkinAuditBus`,
  `SkinAuditChrome` + `SkinViolationBanner` (the impossible-to-miss
  banner), `SkinRouteContractObserver` (NavigatorObserver),
  `ZfaButton` (typed anchor: `contractId`/`contractEnabled`,
  `zfa:` ValueKey, registry lifecycle), `debugTapAnchor`
  (VM-service seam), all behind `kDebugMode`.
- `lib/src/commands/skin_command.dart` + `cli_runner.dart`
  registration — `zfa skin kit` (--route / barrel-derived table,
  skip-if-exists, --force, --dry-run) and `zfa skin verify`
  (match/drift/insufficient-input, exits 0/1/2, `--> fix:` lines,
  `--json` envelope).
- `view_class_builder.dart` + `view_plugin.dart` +
  `generator_config.dart` + `view_command.dart` +
  `create_view_capability.dart` — `--skin` wraps the view getter in
  `SkinContractAuditor(rows: k<ViewName>SkinRows, ...)` with the
  starter row list (hand-edit seam); the kit is emitted
  skip-if-exists when a skin view is generated.
- `app_shell_builder.dart` + `app_shell_command.dart` —
  `--skin-audit` mounts the observer on the `GoRouter`
  (`observers:` with a table from `getAllRoutes()` whereType
  GoRoute, name-else-path) and the banner chrome through
  `MaterialApp.router(builder:)` (null-safe child fallback);
  without the flags the output is byte-identical to the pre-1102
  emission (covered by dedicated byte-compat tests).
- `registration_builder.dart` + `di_plugin.dart` (all 11 emission
  sites) + `app_module_writer.dart` — unregister-first guards
  (`if (getIt.isRegistered<T>()) getIt.unregister<T>();`) +
  `resetDependencies(GetIt getIt)` alongside `setupDependencies`
  (full regen, the AST-merge path via `_ensureResetDependencies`,
  and the day-zero bootstrap barrel).

GREEN runs (Dart 3.13.3, this branch):

```text
$ dart test test/skin/ ... test/plugins/di/di_idempotent_test.dart
00:04 +115: All tests passed!

  test/skin/ (pure core + builder emission)     +82
  test/commands/skin_command_test.dart          +11
  test/plugins/view/view_skin_audit_wrap_test   +7
  test/plugins/app_shell/app_shell_skin_audit   +8
  test/plugins/di/di_idempotent_test.dart       +7
```

The widget test of the emitted kit (written against real Flutter —
see §4) caught and fixed three REAL emission bugs the pure-Dart
suite could not see: `RouteBase.path` vs `whereType<GoRoute>()`,
`BuildContext` vs `Element` at the audit root, and
`NavigatorObserver.didReplace`'s named-parameter signature — plus
the banner-builder's nullable child. That is the compile-check
doing its job; the fixes are in the builder templates and covered
by the re-emission tests.

## 4. The emitted Flutter glue — REAL compile + runtime proof

The framework repo is pure Dart (Constitution VII), so the Flutter
half of the kit can only be proven in a real Flutter target. A
scratch app (`flutter create`, Flutter 3.47.2 / Dart 3.13.2) was
wired with `zuraffa` from THIS branch (path override) +
`zuraffa_flutter` 6.1.0 + `go_router` 17.5.0 from pub; the routing
and DI barrels were hand-written fixtures (the input contracts the
app shell requires — `getAllRoutes()` with builders,
`setupDependencies(GetIt)`); everything else was emitted by THIS
branch's real CLI:

```text
$ dart run bin/zfa.dart skin kit --root <scratch> --route login --route deals
skin kit: wrote <scratch>/lib/src/skin/skin_contract_auditor.dart (routes: 2 …)

$ dart run bin/zfa.dart app shell --skin-audit --force --root <scratch>
✅ App shell generated.
```

Receipts (paths relative to `tdd/receipts/`):
`emitted_kit_sample.dart.txt`, `emitted_my_app_sample.dart.txt`,
`emitted_app_router_sample.dart.txt` — the exact emitted bytes.

```text
$ flutter analyze     # 0 errors, 0 warnings; 6 info lints:
                      # 5× depend_on_referenced_packages (zuraffa arrives
                      # via path override in the scratch — real apps
                      # declare it), 1× type_init_formals (hand-written
                      # fixture file)
$ flutter test --timeout 30s
00:01 +6: All tests passed!
```

The six passing widget tests (`runtime_widget_test.dart.txt`) prove
the pilot's demo semantics against the LIVE tree:

1. **Chaos edit → banner**: text drifts
   `Continue with Google` → `Continue with Goggle`; the next audited
   frame publishes `[google-text] Continue with Google renders` and
   the red `SKIN CONTRACT VIOLATIONS` banner appears (found by
   `find.text`).
2. **Revert → clears**: restoring the text clears the banner on the
   next audited frame.
3. **Rebuild channel**: a rebuild with drifted content re-audits
   (didUpdateWidget rows-updated mark).
4. **Route observer**: an undeclared push (`chaos-route`) publishes
   `route:chaos-route`; the navigator root `/` never flags
   (lesson 3).
5. **debugTapAnchor**: the typed anchor registers while mounted; the
   VM-service seam invokes the REAL onPressed for both
   `signin-guest` and `zfa:signin-guest`; an unknown anchor refuses
   (`false`).
6. **pumpAndSettle settles** — the subscribe-don't-poll proof
   (pilot lesson 5).

Honest limitation: `binding.reassembleApplication()` (the pilot's
literal hot-reload channel) crashes the automated test binding, so
the shipped `reassemble()` override is analyzer-verified and driven
by production hot reload, not by an in-harness widget test; the
sibling channels (listenable, dependency change, row update) are
test-proven above.

## 5. /speckit.tdd.verify — the deterministic gate (REAL run)

```text
$ dart run bin/zfa.dart tdd verify --feature 1102-runtime-skin-contract-auditor
   receipt preflight: skipped (no receipts shipped — proof-carrying
                      generation not in use)
zfa tdd verify: running mutation audit...
   feature: 1102-runtime-skin-contract-auditor
   gate: not_assessed
   reason: no behavior artifacts registered
   killed: 0 / survived: 0 / timed_out: 0 (mutation_was_run: false)
   restoration_verified: true
mutation: gate=not_assessed killed=0 survived=0 timed_out=0
❌ mutation audit gate: not_assessed (no behavior artifacts registered)
```

The deterministic gate reports its honest state: this repo-level
framework spec carries no `tdd/artifacts.json` behavior registry
(the mutation audit applies to registry-driven target features —
exactly the state spec 1005 recorded in its verification.md, and
spec 1002 before it). The REAL red→green evidence for THIS spec's
behaviors is §2–§4 and the emitted-kit widget tests; the gate is
`not_assessed`, not a fabricated score. (Note: the run first failed
the receipt preflight on stale `.zfa/receipts/` entries left by
local full-suite runs pointing at deleted /tmp fixtures —
`.zfa/` is gitignored local state; cleared, then re-run.)

## 6. Full-suite verification

```text
$ dart analyze
333 issues found.      # pristine-master baseline: 333 — identical
                        # (both trees with examples/todo_tdd unresolved,
                        #  the state CI runs in; resolving todo_tdd on
                        #  both trees gives 302 == 302 as well)
$ tools/run_tests_chunked.sh
83 chunks; FAIL: cache + usecase chunks — identical failures to
  pristine master (verified twice: clean git worktree of master
  @ 512a8189 ran the same script; see below)
$ dart format .
Formatted 2225 files (0 changed)  # zero remaining formatting diffs
$ git diff --stat                 # no formatting deltas
```

Chunk-level comparison (identical scripts, identical machine):

| | master @ 512a8189 | this branch |
|---|---|---|
| chunks | 82 | 83 (+ test/skin) |
| `test/plugins/cache/cache_adapter_receipt_test` | `+44 -2` FAIL | `+44 -2` FAIL (same 2 tests) |
| `test/plugins/usecase/usecase_command_grammar_test` | `-1` FAIL | `-1` FAIL (same test) |
| `test/plugins/usecase/usecase_expectation_post_pass_test` | flaky (fails under parallel load, passes isolated) | flaky identically (re-run 3× on both trees: `-2`, `-1`, all-pass on master; `-2`, `-1` on branch — the flake set is shared) |
| everything else | pass | pass |

The analyze baseline: master 333 with `examples/todo_tdd`
unresolved; after `dart pub get` inside `examples/todo_tdd` on BOTH
trees the counts are 302 == 302 — zero issues attributable to this
branch. The 2 cache + 1 usecase-grammar failures are the documented
master pre-existings (spec 1005's verification.md records the cache
one; the grammar one reproduces on the pristine master worktree).

## 7. Success criteria — proved vs not

- PROVED: `zfa skin kit` emits the kit (deterministic bytes, formats
  clean, GENERATED markers, imports `package:zuraffa/skin.dart`)
  with the `--route`-derived or barrel-derived table; skip-if-exists
  preserves hand edits; `--force` regenerates (§3, §4).
- PROVED: `zfa skin verify` verdicts match (exit 0) / drift (exit 1
  with per-route findings + `--> fix:`) / insufficient-input (exit
  2) + `--json` envelope (§3, +11 command tests).
- PROVED: `--skin` view wrap at the view getter with the starter
  row list; without the flag the output carries no auditor tokens
  (byte-compat tests, §3).
- PROVED: `--skin-audit` app shell mounts observer + chrome; without
  the flag the shell output is byte-identical (§3, §4 — the emitted
  shell boots in `flutter test`).
- PROVED: generated DI is unregister-first at all 11 emission sites
  + `resetDependencies` on full regen, the merge path, and the
  bootstrap barrel (§3, +7 DI tests).
- PROVED: the runtime contract semantics on real Flutter 3.47.2 —
  chaos edit → banner, revert → clear, undeclared push → route
  violation, root conforms, debugTapAnchor drives the real
  onPressed, pumpAndSettle settles (§4, 6/6 widget tests).
- PROVED: `dart analyze` 333 == master 333 (pristine state both
  trees; 302 == 302 with todo_tdd resolved on both — zero issues
  attributable to this branch); chunked suite failures identical to
  pristine master; `dart format .` zero diffs (§6).
- NOT ASSESSED: mutation score for the repo-level feature (§5 — no
  behavior registry; honest gate, not a fabricated pass).
- NOT EXERCISED IN-HARNESS: the `reassemble()` hot-reload channel
  (analyzer-verified; `reassembleApplication()` crashes the
  automated binding — documented in §4).

## 8. Reproduction

```bash
dart analyze
tools/run_tests_chunked.sh
dart format .
git diff --stat          # zero remaining formatting diffs

# the emitted-Flutter proof (Flutter 3.47.2):
dart run bin/zfa.dart skin kit --root <flutter-app> --route <r>...
dart run bin/zfa.dart app shell --skin-audit --root <flutter-app>
flutter analyze && flutter test   # 0 errors / all green
```
