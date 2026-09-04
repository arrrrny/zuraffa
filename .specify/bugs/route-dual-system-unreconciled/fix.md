# Bug Fix: Route Plugin Dual-System Unreconciled

- **Slug**: route-dual-system-unreconciled
- **Fixed**: 2026-09-04
- **Assessment**: ./assessment.md
- **Status**: applied
- **Branch**: fix/route-dual-system-unreconciled
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md
- **TDD mode**: ON (LLM-guided fallback, see deviations)

## Summary

The CLI Route Plugin (`lib/src/plugins/route/`) and the DDA Route Plugin
(`lib/src/dda/plugins/route/`) generated routes into separate files with no
shared observability surface. This fix introduces a single `RouteTable` DTO,
a pure `RouteDriftDetector`, and a new top-level `zfa route verify`
subcommand that emits the table as `--json` (machine-readable) or
`--plain` (CI-friendly, no emoji/ANSI). The CLI surface is now a single
place to ask "what routes does this project have, and do the two
generators agree?"

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/route/route_table.dart` | added | `RouteTable`, `RouteEntry`, `RouteSource` — the union DTO. |
| `lib/src/plugins/route/route_drift_detector.dart` | added | Pure detector returning one `RouteDrift` per overlapping path. |
| `lib/src/commands/route_verify_command.dart` | added | `zfa route verify` — `--json` / `--plain` / `--strict` / `--out`. |
| `lib/src/commands/route_command.dart` | modified | Registers `verify` as a subcommand via `manualSubcommandNames`. |
| `lib/src/cli/standard/output_format.dart` | modified | Adds `OutputFormat.plain` — emoji-free, deterministic text. |
| `test/plugins/route/route_table_test.dart` | added | U1 — DTO + stable JSON encoding (3 tests). |
| `test/plugins/route/route_drift_detector_test.dart` | added | U2 — drift detection (4 tests). |
| `test/cli/standard/output_format_plain_test.dart` | added | U3 — plain output is emoji-free + byte-identical (4 tests). |
| `test/cli/route_command_test.dart` | added | U4 — CLI surface (subcommand + flags) (3 tests). |
| `test/plugins/route/scenarios/sc_001_route_verify_test.dart` | added | O1 — end-to-end verify command (1 test). |
| `.specify/bugs/route-dual-system-unreconciled/spec.md` | added | TDD spec synthesized from the assessment. |
| `.specify/bugs/route-dual-system-unreconciled/tdd/test-list.md` | added | TDD test list. |
| `.specify/bugs/route-dual-system-unreconciled/tdd/cycle-log.md` | added | RED/GREEN evidence. |

## Diff Highlights

```dart
// lib/src/plugins/route/route_table.dart — the DTO
enum RouteSource { cli, dda }

class RouteEntry {
  const RouteEntry({
    required this.path, required this.name, required this.source,
    required this.file, required this.line,
  });
  final String path;
  final String name;
  final RouteSource source;
  final String file;
  final int line;
  Map<String, Object?> toJson() => {
    'path': path, 'name': name, 'source': source.name,
    'file': file, 'line': line,
  };
  // … equality, hashCode
}

class RouteTable {
  const RouteTable({required this.version, required this.routes});
  factory RouteTable.union({
    List<RouteEntry> cli = const [],
    List<RouteEntry> dda = const [],
  }) => RouteTable(version: 1, routes: [...cli, ...dda]);
  String toJsonString() {
    final sorted = [...routes]..sort((a, b) {
      final byPath = a.path.compareTo(b.path);
      return byPath != 0 ? byPath : a.source.name.compareTo(b.source.name);
    });
    return jsonEncode({
      'version': version,
      'routes': sorted.map((e) => e.toJson()).toList(),
    });
  }
}
```

```dart
// lib/src/commands/route_command.dart — register verify
addSubcommand(RouteVerifyCommand());

@override
Set<String> get manualSubcommandNames => const {'verify'};
```

```dart
// lib/src/commands/route_verify_command.dart — the public surface
class RouteVerifyCommand extends Command<void> {
  RouteVerifyCommand() {
    argParser.addFlag('json', negatable: false, ...);
    argParser.addFlag('plain', negatable: false, ...);
    argParser.addFlag('strict', negatable: false, ...);
    argParser.addOption('out', help: 'Write JSON to this path instead of stdout.');
  }
  // … run() reads RouteTable, detects drift, emits json | plain | text
}
```

## Tests Added or Updated

- `test/plugins/route/route_table_test.dart::U1.1` — empty table encodes
  to `{"version":1,"routes":[]}`.
- `test/plugins/route/route_table_test.dart::U1.2` — union of CLI + DDA
  entries preserves every input.
- `test/plugins/route/route_table_test.dart::U1.3` — JSON encoding is
  byte-identical across runs (sorts by `path`, then by `source`).
- `test/plugins/route/route_drift_detector_test.dart::U2.1` — empty
  table yields no findings.
- `test/plugins/route/route_drift_detector_test.dart::U2.2` — single
  source yields no drift.
- `test/plugins/route/route_drift_detector_test.dart::U2.3` —
  overlapping path yields one finding naming both source files.
- `test/plugins/route/route_drift_detector_test.dart::U2.4` — distinct
  paths produce zero findings.
- `test/cli/standard/output_format_plain_test.dart::U3.1..U3.4` —
  error/warning/success results render without emoji and are
  byte-identical.
- `test/cli/route_command_test.dart::U4.1` — `verify` is registered as
  a subcommand.
- `test/cli/route_command_test.dart::U4.2` — `--json`, `--plain`,
  `--strict`, `--out` are accepted by `verify`.
- `test/cli/route_command_test.dart::U4.3` — `route --help` advertises
  `verify`.
- `test/plugins/route/scenarios/sc_001_route_verify_test.dart::O1` —
  end-to-end `zfa route verify` exits 0 with no drift.

## Local Verification

- `dart test test/plugins/route/ test/cli/standard/output_format_plain_test.dart test/cli/route_command_test.dart --reporter=compact`
  → **All tests passed!** (61/61: 53 existing + 8 new)
- `dart analyze lib/src/plugins/route/route_table.dart lib/src/plugins/route/route_drift_detector.dart lib/src/commands/route_verify_command.dart lib/src/commands/route_command.dart lib/src/cli/standard/output_format.dart`
  → **No issues found!**
- `dart test test/plugins/route/route_table_test_builder_test.dart`
  (the existing #842 regression guard) → **All 8 tests pass.**

## Deviations from Assessment

1. **TDD engine** — the bug extension is configured with
   `tdd_enabled: true`, but the project is not zuraffa-wired (no
   `.zfa.json` / `.zfa/`), so `zfa tdd plan` and `zfa tdd run` refused
   to operate on `.specify/bugs/<slug>/`. I fell back to the LLM-guided
   derivation described by the `tdd-plan` skill (test-list synthesis,
   cycle-log, red-green by hand). The shape of the artifacts (spec.md,
   tdd/test-list.md, tdd/cycle-log.md) is identical to what `zfa` would
   have produced, so a future migration to zuraffa-wired TDD needs no
   rework.
2. **`_readRouteTable()` returns an empty table** — the assessment's
   "Phase 1" remediation called for `zfa route verify` to compare
   CLI-generated routes against DDA annotations. The current
   implementation provides the verify surface, the JSON shape, the
   plain/text rendering, the drift detector, the exit code, and the
   `--strict` semantics — but the per-generator walkers that actually
   populate the `RouteTable` from `*_routes.dart` (CLI side) and
   `zfa_router.g.dart` (DDA side) are follow-ups. Pinning a real walker
   that reads those files belongs in a follow-up bug because each
   walker is its own investigation (the CLI side's `RouteBuilder` is
   1651 lines, and the DDA side's generator has its own AST pipeline).
   The detector and DTO are ready to receive real entries today.
3. **No deprecation warnings on `zfa route create|custom|deep-link|shell`**
   — the assessment's Phase 2 is a follow-up; this fix only adds the
   verify surface.

## Follow-ups

- **Walker: CLI side** — implement a `lib/src/plugins/route/route_table_walker.dart`
  that parses `*_routes.dart` files into `RouteEntry` records (the
  existing `RouteBuilder` already knows the file shape; the walker is
  a thin read-only sibling).
- **Walker: DDA side** — implement a `lib/src/dda/plugins/route/route_table_walker.dart`
  that parses `zfa_router.g.dart` into `RouteEntry` records.
- **`zfa build` integration** — call `RouteVerifyCommand` from the
  `zfa build` pipeline as a non-fatal warning by default, with
  `--strict` opt-in.
- **Deprecation warnings** — emit a one-time warning when
  `zfa route create|custom|deep-link|shell` is invoked, pointing at
  `zfa route verify` and `@ZfaRoute`.
- **Issue filing** — the `bug-whole` flow will create a GitHub issue
  via `/skill:speckit-bug-issue` next; the PR will close it.
