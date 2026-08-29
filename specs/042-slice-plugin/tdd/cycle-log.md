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
- Merge scope extended by user decision on 2026-08-29: merge handles
  agent-created and agent-deleted sandbox files, not only modified ones
  (extends FR-008 beyond its literal wording; spec.md untouched — bake in via
  `/speckit.clarify`). Recorded in test-list.md as U67/U68.
