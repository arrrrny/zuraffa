# 1510-default-selector-skips-regression-files — Technical Plan

- **Feature**: 1510-default-selector-skips-regression-files
- **Created**: 2026-09-13
- **Source spec**: `.specify/specs/1510-default-selector-skips-regression-files/spec.md`

## Technical Context

### Selector mechanics (verified against test_core 0.6.20 source)

- `dart_test.yaml` top-level `exclude_tags: slow` is the default preset's
  suite-level filter. `Configuration.merge` documents: excludeTags is
  UNIONed on merge, includeTags is intersected.
- CLI flags have higher precedence than the package config, but
  `--exclude-tags` merges by union — CI's `dart test test
  --exclude-tags flutter` therefore excludes `slow ∪ flutter`.
- Presets REPLACE the keys they declare: `--preset=all` sets
  `exclude_tags: "false"` (a nonexistent tag), removing the default
  exclusion; `--preset=regression` adds `include_tags: regression`.
- No per-path config exists in `dart_test.yaml` (no path-key parsing in
  `_ConfigurationLoader`), and nothing can detect "a path was passed on
  the CLI" — so criterion 1 (selector-side fix) is not expressible; the
  fix must be tagging-side (criterion 2).

### Current tag landscape (measured)

| Population | Count | Default preset |
|---|---|---|
| Test files total | 1290 | runs |
| Files tagged `slow` | 261 | excluded |
| Files tagged `slow` with NO tier tag (violates the "every slow test also carries a tier tag" convention) | 157 | excluded |
| The two named files | 2 | excluded (the bug) |
| Files tagged `regression` without `slow` | ~11 | runs |

CI lanes that select tests:
- `ci.yaml#dart_core`: `dart test test --exclude-tags flutter` (fast lane,
  30-min timeout, latest master run: 1339 s ≈ 22.3 min → ~7.7 min
  headroom). Absorbing `make_command_test.dart` (42 behaviors, each
  spawning a temp fixture with `dart pub get` + real `dart test`
  subprocesses) would blow the budget — the lane must keep excluding them.
- `conformance.yml`: two default-selector file gates + one
  `--preset=all` slow-tagged gate (the established opt-in pattern).
- `tools/run_tests_chunked.sh`: per-directory
  `dart test <dir> --exclude-tags flutter` (fast tier, local).

### Decision: tag swap with a lane-guard tag

Both named files: `@Tags(['slow'])` → `@Tags(['regression', 'e2e'])`.

- `regression` — makes the files first-class members of the regression
  tier (the issue title itself calls them "regression files", and the
  issue body's workaround names the "explicit regression/all selector" as
  the correct lanes). `--preset=regression` and `--preset=all` now select
  them (SC-4). The repo's convention "every slow test also carries a tier
  tag" becomes satisfiable-in-spirit: the files carry a tier tag and a
  weight tag, but not the default-excluded `slow`.
- `e2e` — the weight/lane-guard tag: marks heavy end-to-end suites that
  drive the real CLI against temp projects. CI's fast lane excludes it
  explicitly, keeping the lane's composition byte-identical (SC-3).

`dart_test.yaml`: declare `e2e:` in the `tags:` map (no
unknown-tag warnings) and document it in the header comment.

`ci.yaml#dart_core`: `--exclude-tags flutter` →
`--exclude-tags "flutter || e2e"` — boolean selector syntax, same merge
semantics as before; the fast lane's selected set is unchanged because
both files were slow-excluded before and e2e-excluded after.

### Effect matrix

| Invocation | Before | After |
|---|---|---|
| `dart test test/plugins/tdd/make_command_test.dart` | exit 79, 0 tests | exit 0, 42 tests |
| `dart test test/plugins/tdd/make_command_declared_071_test.dart` | exit 79, 0 tests | exit 0, 1 test |
| default `dart test` (local fast tier) | excluded | included (+2 files, local-only cost) |
| CI `dart_core` fast lane | excluded | excluded (unchanged) |
| `--preset=regression` | NOT selected | selected (additive, honest lane) |
| `--preset=all` | selected | selected |
| `--preset=integration/property/benchmark`, `--tags ffi`, flutter lane | untouched | untouched |

### Risks & mitigations

- **Risk**: local default-tier runs get slower (+2 heavy files).
  **Mitigation**: documented in `dart_test.yaml` header; the chunked
  runner already exists for constrained agents; the issue's success
  criteria explicitly prioritize direct-path honesty (SC-1/SC-2).
- **Risk**: `e2e` collides with a future upstream tag name.
  **Mitigation**: declared in the tags map; tag names are repo-local.
- **Risk**: `--exclude-tags "flutter || e2e"` boolean syntax.
  **Mitigation**: verified against the installed test_core (boolean
  selector parsing, same as `--tags`); verified by running the exact CI
  command shape locally in the verification phase.

## Non-goals

- Untagging the other 155 slow-only files (out of scope; issue names two
  files; a mass re-tag is a separate spec).
- Any change to test logic, fixture helpers, `MakeCommand`, or the state
  machine.
- A selector-side "paths override tags" feature in `package:test` itself.
