# Bug 1103 — `zfa datasource check` — add `--json` envelope (last unjsoned `--> fix:` emitter)

- **Severity:** medium
- **Class:** honesty / fleet convergence (A+ fleet parity)
- **Found:** during re-grade of #977

## Symptom

`DataSourceCheckCommand` emits its verdict only as human text + exit codes.
Sibling commands `CacheVerifyCommand`, `RouteVerifyCommand` and
`StateCreateCommand` all ship `--json` envelopes with `schema: 1`. Datasource
check is the last manual emitter without a machine verdict, so agents must
scrape it the old way.

## Evidence

`lib/src/commands/datasource_check_command.dart` — no `--json` flag, no
`jsonEncode` envelope; emits `--> fix:` lines + exit code only. Contrast:

- `lib/src/commands/cache_verify_command.dart` — `argParser.addFlag('json')`
  + `jsonEncode(report.toJson())`, no prose in JSON mode;
- `lib/src/commands/route_verify_command.dart` — schema-1 verdict envelope
  (`{'schema': 1, 'verdict': ..., 'findings': [...]}`);
- `lib/src/commands/state_create_command.dart` — `StateCreateVerdict` with
  `schema: 1` integer key.

## Proposal

Add `--json` to `DataSourceCheckCommand` returning
`{verdict: match|drift, findings: [{kind, file, member, fix}], schema: 1}`.
Exit codes stay (0 match / 1 drift). Update existing
`datasource_check_command_test.dart` negative cases to assert the envelope
shape on drift, not just the text.

## Acceptance criteria

1. `zfa datasource check Product --json` emits the envelope; test asserts
   `schema`, `verdict`, `findings[*].kind`.
2. Drift path (`--> fix:`) is still printed for humans when `--json` is
   absent.
3. Sibling commands converge on the same envelope shape.

## Hard constraints

- Fix ONLY the `--json` envelope for datasource check; do not change the
  parity gate logic.
- One PR for the bug.
