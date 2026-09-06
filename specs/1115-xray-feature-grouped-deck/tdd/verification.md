# TDD Verification — feature `1115-xray-feature-grouped-deck`

Real red → green evidence for spec 1115 (issue #1115: feature-grouped xray
deck + XrayLayer decorator — xray/slice/auditor share one FeatureId).
Every number below is from an actual run on this branch — nothing is
projected.

## The cycle (red → green → refactor → verify)

### RED (recorded before any implementation existed)

Command: `dart test` over the 8 spec-1115 test files
(`test/domain/feature_contract/feature_id_test.dart`,
`test/domain/feature_contract/xray_layer_decorators_test.dart`,
`test/plugins/xray/feature_grouping_test.dart`,
`test/commands/xray_check_cli_test.dart`,
`test/plugins/feature/xray_feature_capability_test.dart`,
`test/plugins/xray/xray_node_feature_test.dart` (typed),
`test/skin/skin_audit_controller_feature_test.dart`,
`test/core/plugin_system/plugin_context_feature_id_test.dart`).

Result: **all 8 files failed to load — 108 compile errors**, all pointing
at exactly what the issue says is missing:

- `Undefined name 'FeatureId'` (the typed id did not exist — xray took a
  raw String);
- `Undefined class 'XrayLayerDecorators'` / `XraySplit` (no
  `@XrayLayer('engine'|'skin'|'shared')` decorator existed);
- `Couldn't find the subcommand 'check'` in the `xray` runner (no
  `zfa xray check`);
- `Undefined class 'XrayFeatureCapability'` (no typed capability, no
  `feature: { type: 'FeatureId', required: true }` schema);
- `featureId: 'login'` string-argument errors against the typed node field.

Evidence: red run output preserved verbatim in the session log
(`/home/z/my-project/scripts/red-evidence.txt`, 108 `Error:` lines).

### GREEN (implementation + suite results)

Final command: `dart test test/domain/feature_contract/
test/plugins/xray/ test/commands/xray_check_cli_test.dart
test/plugins/feature/ test/skin/ test/core/plugin_system/
test/core/transaction/`

Result: **+330 passing, 0 failing** (green evidence:
`/home/z/my-project/scripts/green-evidence.txt`).

The issue's success criteria, each PROVED by a named test:

1. *"An engine/ file in the 004 slice has @XrayLayer('engine'); a skin/
   view has @XrayLayer('skin')"* — `feature_grouping_test.dart` →
   `the composer writes the xray_layer decorator (criterion 2)`: composes
   a real slice from a sandbox project and asserts
   `engine/usecases/login_usecase.dart` carries
   `// @XrayLayer('engine')` + `// @FeatureOwned('004-login-ui')`, and
   `skin/views/login_view.dart` carries `// @XrayLayer('skin')`. The
   generated harness (router, boundary mock, slice DI) is stamped too.
2. *"zfa xray deck --feature=004-login-ui groups nodes by feature, prints
   layer breakdown"* — `feature_grouping_test.dart` → criterion 3 test:
   the deck command output contains the feature id, `Layer breakdown`,
   `engine`/`skin` counts, and the deck artifact itself is stamped
   `@FeatureOwned` + `@XrayLayer('skin')` (routed contract → skin side).
3. *"zfa xray check 004-login-ui exits 0 on a clean slice, exits 1 with
   named violators otherwise"* — `feature_grouping_test.dart` criterion 4
   (clean → exit 0; stripped anchor → exit 1 naming `login_view.dart`;
   deck file outside the slice → exit 1 naming `rogue_deck.dart`;
   unknown id → exit 64) + `xray_check_cli_test.dart` (missing slice →
   compose hint + exit 1; decorator/half mismatch → exit 1; clean
   breakdown report → exit 0).
4. *"A test in test/plugins/xray/feature_grouping_test.dart proves the
   grouping"* — present; additionally proves node-level grouping
   (typed `FeatureId` map keys) and JSON round-trip typedness
   (criterion 1 tests).

### Refactor

No separate refactor pass was needed; the stamping logic was consolidated
once mid-cycle (`XrayLayerDecorators.stamp` delegates to `stampSplit`,
the slice composer passes the SLICE-tree-derived split explicitly) —
suite re-run green after each consolidation.

## Gates (actually run on this branch)

### 1. `dart analyze` on every changed/new file

**No issues found** (all 22 files: 11 modified lib files, 4 new lib
files, 7 new/updated test files). Three transient warnings (2 unused
imports, 1 unused element) were fixed during the cycle; the re-run is
clean.

### 2. Full fast suite, chunk-by-chunk

Chunk list from the repo's disk-safe runner
(`tools/run_tests_chunked.sh`), `dart test <chunk> --exclude-tags
flutter` per chunk, kernel cache cleared between chunks.

Every fast-suite chunk green:

- `test/agent` +233, `test/app_update` +6, `test/cli` +200,
  `test/config` +10, `test/core/ast` +18, `test/core/branding` +13,
  `test/core/builder` +18, `test/core/context` +12,
  `test/core/generation` +10, `test/core/module` +39,
  `test/core/planning` +13, `test/core/plugin_system` +39,
  `test/core/project` +6, `test/core/transaction` +5,
  `test/core/usecase_interceptor` +6, `test/dda` +59, `test/domain` +62,
  `test/engine` +45, `test/feature_flags` +54, `test/mcp` +71,
  `test/plugins/api` +30, `test/plugins/app_shell` +83,
  `test/plugins/cache` +29, `test/plugins/datasource` +37,
  `test/plugins/di` +46, `test/plugins/feature` +13,
  `test/plugins/mock` +142, `test/plugins/module` +2,
  `test/plugins/presenter` +3, `test/plugins/provider` +28,
  `test/plugins/route` +86, `test/plugins/service` +27,
  `test/plugins/skeleton` +96, `test/plugins/skin_contract` +30,
  `test/plugins/state` +21, `test/plugins/strategy` +26,
  `test/plugins/sync` +31, `test/plugins/test` +47,
  `test/plugins/tui` +67, `test/plugins/usecase` +42,
  `test/plugins/view` +11, `test/plugins/xray` +142,
  `test/plugins/gym` +40, `test/plugins/benchmark` +59,
  `test/plugins/method_append` +4, `test/plugins/shadcn` +42,
  `test/plugins/sqlite` +8, `test/commands` +261, `test/skin` +84,
  `test/state` +68, `test/testing` +15, `test/utils` +99,
  `test/zap` +76, `test/scripts` +2, `test/session` +20,
  `test/share` +5, `test/simulation` +192, `test/skew` +29,
  `test/secure_storage` +11, `test/helpers` +9, `test/graphql` +192,
  `test/logging` +6, `test/migration` +20, `test/biometrics` +7,
  `test/clipboard` +6, `test/device` +6, `test/package_sdk` +42,
  `test/property` +10, `test/i18n` +11, `test/tdd/072` +25,
  `test/tdd/073` +22, `test/tdd/074` +21, `test/tdd/075` +22,
  `test/tdd/078` +14, `test/tdd/079` +13, `test/tdd/0966` +8,
  `test/tdd/bug-tdd-run-baseline-timeout` +3.

Environment notes (NOT regressions, both verified against clean master):

- `controller`/`presenter` COMPILE tests invoke `flutter pub get` — this
  sandbox has no Flutter SDK; with the runner's own `--exclude-tags
  flutter` both chunks pass (structural tests +5 / +3). The chunked
  runner excludes flutter-tagged tests by design.
- `test/plugins/slice` `slice_worktree_capability_test.dart` journal
  glue-back test fails here; `git stash -u` on a clean master reproduces
  the SAME failure (environmental — git worktree sandbox), so it is
  pre-existing and unrelated to this branch. All other slice tests pass,
  including the full spec-1114 compose suite.
- Slow-tier folders (`test/tdd/models`, `test/tdd/theater`,
  `test/tdd/services/*`, `test/tdd/corpus_economics`, `test/integration`,
  `test/core/dependencies`, `test/core/proof`, `test/benchmark`,
  `test/tdd/077-make-engine-preset`, `test/tdd/scenarios`) run zero fast
  tests by design (`No tests ran` + the runner's sanctioned skip path).

### 3. `dart format`

Applied to all changed/new files; formatting-only deltas are folded into
the feature commit.

## Mutation notes

This is a CLI/tooling spec with no registered behavior artifacts for the
engine's automated mutation bucket (the same class as landed specs 1114
and 1138: `mutation_was_run: false`, buckets empty). Manual mutant checks
performed during the cycle (each restored byte-exact afterwards):

- stripped the composer's stamp call → criterion-2 grouping test RED;
- reverted `forContract`'s routed-contract fallback to `shared` →
  criterion-3 deck test RED;
- removed generatedFiles from the check's slice set → clean-slice check
  test RED (the router was flagged as outside the slice).

## Acceptance-criteria coverage

| Issue requirement | Where | Status |
| --- | --- | --- |
| `XRayNode.featureId: FeatureId` (typed) | `xray_node.dart`; criterion-1 tests | PROVED |
| `@XrayLayer('engine'\|'skin'\|'shared')` decorator, written by codegen | `xray_layer_decorators.dart` + `PluginManager.run` stamp wire + composer stamping; criterion-2 tests | PROVED |
| `zfa xray deck --feature` groups by feature + layer breakdown | `xray_deck_command.dart` `_printFeatureLayerBreakdown`; criterion-3 test | PROVED |
| `zfa xray check <feature-id>` (SliceBoundary, 3 checks, exit codes) | `xray_check_command.dart`; criterion-4 + CLI tests | PROVED |
| SliceManifest xrayLayer + audit-bus feature = one FeatureContract.id | `FeatureSliceManifest.feature` (1114) + `SkinAuditController.feature: FeatureId?` (typed) + receipt `input.feature` (1098, unchanged); bus test | PROVED |
| `PluginContext.featureId` wire | `PluginContextFeatureContract.featureId` extension; wire test | PROVED |
| `XRayCapability` typed arg + schema validation vs registered contracts | `xray_feature_capability.dart` (`feature: {type: 'FeatureId', required: true}`, `validateArgs`); capability tests | PROVED |
| `test/plugins/xray/feature_grouping_test.dart` proves grouping | file exists, 10 tests | PROVED |
