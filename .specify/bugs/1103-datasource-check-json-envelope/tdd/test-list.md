# TDD test list — bug 1103 (`datasource check --json` envelope)

File under test: `lib/src/commands/datasource_check_command.dart`
Test file: `test/plugins/datasource/datasource_check_command_test.dart`

| # | Test | Asserts | Status |
|---|------|---------|--------|
| T1 | `impl missing an interface method exits 1 naming method + file` (extended) | text path unchanged (`--> fix:`, method, file) AND the same drift under `--json` emits `{schema: 1, verdict: 'drift'}` with a `missing-method` finding | green |
| T2 | `impl @override method absent from the interface exits 1` (extended) | text path unchanged AND `--json` envelope carries an `extra-override` finding | green |
| T3 | `sqlite variant missing interface methods is caught` (extended) | text path unchanged AND `--json` findings name members `delete` + `watch` | green |
| T4 | `missing interface file exits 1 with a fix line` (extended) | text path unchanged AND `--json` emits exactly one `missing-interface` finding | green |
| T5 | `match path emits the schema-1 envelope with empty findings` | `--json` on parity → `{schema: 1, verdict: 'match', findings: []}`, exit 0 | green |
| T6 | `drift findings carry the full {kind, file, member, fix} shape and no human prose leaks into stdout` | every finding has all four keys; `missing-method`/`getList`/impl file present; no `--> fix:` prose in JSON mode; exit 1 | green |

Pre-existing tests kept green (no behavior change on the text path):
fresh-generation parity, full sqlite variant parity, usage exit 64,
unknown entity exit 1.
