# Cycle Log: Slice Plugin — Context-Isolated Codebase Extraction

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test` -> 2844 passed, 1 skipped, 8 failed
- commit: `ee0aa612`
- recorded: cycle 0, before any change (2026-08-29)
- suite_baseline: **red** — the loop must not start on top of this. All 8
  failures predate the feature and are unrelated to the slice plugin:
  - `test/commands/api_command_test.dart: ApiCommand zfa api <Entity> generates the bridge and does not throw`
  - `test/commands/initialize_dart_inplace_test.dart: InitializeCommand --dart in-place bootstrap (issue #393) --dart non-dry-run on repo without pubspec creates minimal pubspec in-place`
  - `test/commands/make_command_xray_default_test.dart: explicit xray:false in --from-json is preserved over the config default`
  - `test/commands/plugin_command_mcp_test.dart: PluginCommand.execute mcp mcp alias with --force writes the scaffolded files`
  - 4 further failures not enumerated in the reporter tail (it truncates); a
    full compact-reporter re-run is being captured to enumerate them and will
    be noted under Notes and deviations when it lands.

## Notes and deviations

- The stack profile (`.specify/memory/tdd-profile.md`) predates frontmatter
  format and names the benchmark plugin in its scoped commands; feature-scoped
  commands in the test list are adapted from it. Consider
  `/speckit.tdd.setup refresh`.
- Baseline failure enumeration (second full run, compact reporter, same commit
  `ee0aa612`): 2845 passed, 1 skipped, 7 failed. Failing:
  - `test/commands/api_command_test.dart: ApiCommand zfa api <Entity> --domain <name> still generates the bridge`
  - `test/commands/make_command_xray_default_test.dart: absent xray key falls back to .zfa.json xrayByDefault:true`
  - `test/dda/route_build_stage_test.dart: build command wiring (subprocess) zfa build --dda-routes-only produces the router file`
  - `test/dda/route_perf_test.dart: 100 annotated Views compile into one config in under 2 seconds`
  - `test/package_sdk/package_e2e_test.dart: U30/SC-001: scaffold → pub get → analyze → entity → make → build, zero manual edits, under 5 minutes`
  - `test/plugins/benchmark/scenarios/sc_003_overhead_test.dart: overhead under 5 percent`
  - `test/regression/issue_495_core_commands_no_flutter_import_test.dart` (failed to load)
- The baseline is red AND partially non-deterministic: run 1 (2844/-8) and
  run 2 (2845/-7) failed on different tests. The varying entries are
  perf-threshold tests (`route_perf`, `sc_003_overhead`, `package_e2e`
  "under 5 minutes"), subprocess tests (`route_build_stage`), and xray-default
  tests that fail on different cases per run. All predate this feature and are
  unrelated to the slice plugin, but `/speckit.tdd.verify` must treat only
  `test/plugins/slice/` results as feature evidence, never the repo-wide count.
- Merge scope extended by user decision on 2026-08-29: merge handles
  agent-created and agent-deleted sandbox files, not only modified ones
  (extends FR-008 beyond its literal wording; spec.md untouched — bake in via
  `/speckit.clarify`). Recorded in test-list.md as U67/U68.
