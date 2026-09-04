# Bug Issue: [ZIKZAK-REBUILD] Fleet exit-code + receipt honesty sweep (T-TRACK)

- **Slug**: lying-success-sweep-995
- **Fetched**: 2026-09-04T00:00:00Z
- **Issue**: 995
- **URL**: https://github.com/arrrrny/zuraffa/issues/995
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, tdd

## Body

# [ZIKZAK-REBUILD] Lying-success sweep: fleet-wide exit-code + receipt honesty pass

## Context
Per the plugin fleet report (`.zfa-reports/01-zuraffa-plugin-fleet-report.md`), ~15 plugins exit 0 on error, crash on bare invocation, or print success before verification. The vision's first sentence — "a harness that makes lying impossible" — is violated ~15 times across the fleet.

## Scope (all verified by grep + spot-read)

Plugins with `exit 0 on error` or `print success before verify`:
`view`, `controller`, `datasource`, `shadcn`, `xray deck`, `gym`, `gql`, `graphql generate/introspect`, `feature`, `presenter`, `api`, `module`, `observer`, `cache` (RangeError on bare `zfa cache`), `sync` (RangeError), `observer` (RangeError + exit 0).

**Fixed plugins (for reference):** `state`, `di`, `repository`, `provider`, `service`, `sqlite`, `test` — they already call `reportSubcommandUsage()` + exit 64, or the #769 zero-files guard. Sweep these fixes to the rest.

## Deliverable
1. Every command layer above calls `reportSubcommandUsage()` on bare invocation → exit 64.
2. Every failure branch in `run()` sets `exitCode` to non-zero (1 for generation failure, 2 for validation).
3. `view_command.dart:131` `✅ Generated view and routes successfully!` removed or gated on actual verification.
4. `shadcn_command.dart:42-46` and `:78-80` set exit codes.
5. `cache_command.dart:28` and `sync_command.dart:37` — port `reportSubcommandUsage()` (the `rest.first` RangeError crash).

## Exit criterion
- `dart test test/` passes with zero regressions.
- A new property test (`test/property/lying_success_test.dart`) walks every registered command and asserts: when the operation fails (bad args, missing files), the exit code is non-zero.

## Evidence (from fleet report)
- `view_command.dart:50-56` — named in open issue #767; fix via `reportSubcommandUsage()`.
- `controller_command.dart:33-36` — same.
- `datasource_command.dart:50-53,80-82` — two exit-0 paths.
- `cache_command.dart:28` — bare `zfa cache` RangeErrors.
- `gym_command.dart:146-150` — missing-name exits 0.
- `xray_deck_command.dart:123,156` — `print Error:` with no exitCode.

## Comments

None.
