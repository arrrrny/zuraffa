# TDD Test List: dart format Robustness in a Fresh Clone [SPEC 1506]

**Feature ID:** 1506-format-fresh-clone-robustness
Derived from: [spec.md](../spec.md) FR-1..FR-3 (FR-4 is non-behavioral
documentation, verified not tested).

Behavior unit = one observable runner/command contract, hermetic
(recording process runner, temp-dir fixtures — the
`entity_builder_preflight_test.dart` / `_RecordingRunner` conventions).

## Behaviors

### U1 — Empty scope is a no-op (FR-2 trivial guard, spec D4 adjacent)
- **Given** `FormatRunner` with a recording runner
- **When** `formatPaths([])`
- **Then** no process is spawned, result is skipped
  (`formatRan == false`, `pubGetRan == false`).

### U2 — Tree-wide scope is rejected before any process (FR-2)
- **Given** `FormatRunner` with a recording runner
- **When** `formatPaths` is called with `.`, `./`, `..`, the absolute
  package root, or its parent
- **Then** `ArgumentError` is thrown; recorder stays empty (no pub get,
  no format ever spawned) — the guard resolves scopes before comparing,
  so the `..`/absolute-root bypasses are closed.

### U3 — Missing resolution: pub get enforced BEFORE format (FR-1)
- **Given** temp project WITHOUT `.dart_tool/package_config.json`
- **When** `formatPaths(['lib/src/domain/entities'])`, injected runner
  succeeds for both commands
- **Then** invocation order is exactly
  [`dart pub get --no-example`, `dart format lib/src/domain/entities`];
  result reports `pubGetRan == true`, `formatRan == true`,
  `warning == null`.

### U4 — Unresolvable: format SKIPPED, exactly one warning (FR-1)
- **Given** temp project WITHOUT package config; injected runner fails
  the pub get (exit 1)
- **When** `formatPaths([...])`
- **Then** the formatter is NEVER spawned (no `dart format` in
  invocations), result is skipped with a single actionable warning
  (mentions `pub get`; mentions `flutter pub get` remediation).

### U5 — Resolution present: format only, scoped (FR-1 fast path)
- **Given** temp project WITH a seeded `.dart_tool/package_config.json`
- **When** `formatPaths(['lib/src/domain/entities'])`
- **Then** exactly one invocation: `dart format
  lib/src/domain/entities`; no pub get; `warning == null`; the
  formatter's captured output is carried in `result.output` (the
  summary the CLI must not drop now that `inheritStdio` is gone).

### U6 — Scoped args are trimmed/normalized before the process (FR-3 support)
- **Given** seeded fixture, whitespace-padded scope
  `[' lib/src/domain/entities ']`
- **When** format runs
- **Then** the format invocation's args carry the normalized scope
  (`lib/src/domain/entities`, never the padded original) and NEVER a
  bare `.` / `./` / `lib` / `test` element.

### U7 — EntityCommand format scope (FR-3, integration)
- **Given** the #1322 hermetic entity fixture (temp project, seeded
  package config, resolvable builder deps) and an injected recording
  FormatRunner
- **When** `EntityCommand.execute(['create', '-n', 'StreamEvent',
  '--field', 'kind:String', '--dart-format'], exitOnCompletion: false)`
- **Then** the format invocation's args equal
  `['format', 'lib/src/domain/entities']` — the generated entity tree,
  never `.` — and `dart format` is invoked exactly once.

### U8 — EntityCommand enforcement order without resolution (FR-1 integration)
- **Given** the same fixture WITHOUT seeded package config
- **When** the same create+format runs (injected recording runner used
  for BOTH pub get and format)
- **Then** the recorded order is `dart pub get --no-example` strictly
  before `dart format lib/src/domain/entities`.

## Out of scope (constraint-documented)

- TDD pass registry format pass command string (`dart format lib/`) —
  receipt-pinned; state-machine constraint (spec.md, plan.md D5).
- Make command — untouched per hard constraints.

## Red evidence

Recorded in [cycle-log.md](cycle-log.md) — U1–U8 red against
pre-implementation tree (missing FormatRunner = compile failure red;
U7/U8 red on missing injection seam).
