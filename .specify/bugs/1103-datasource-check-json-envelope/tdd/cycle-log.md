# TDD cycle log — bug 1103 (datasource check `--json` envelope)

Toolchain: Dart SDK 3.13.3 (stable), Linux x64. All commands run at the repo
root unless noted.

## RED (before the fix — flag unrecognized, text-only verdicts)

Real-CLI reproduction against a minimal drift fixture
(`abstract class ProductDataSource { get; getList; }` +
`ProductRemoteDataSource implements ProductDataSource` missing `getList`):

Command: `dart run bin/zfa.dart datasource check Product --json`

```text
❌ Could not find an option named "--json".
Usage: zfa datasource check [arguments]
-h, --help    Print this usage information.

Run "zfa help" to see global options.
```

Command: `dart bin/zfa.dart datasource check Product` (same fixture, no flag)

```text
❌ datasource check failed for `Product`: 1 parity divergence(s) between `ProductDataSource` and its implementations.
--> fix: implementation `ProductRemoteDataSource` is missing a method declared in `ProductDataSource` — method `getList`, file `lib/src/data/datasources/product/product_remote_datasource.dart` (interface: `lib/src/data/datasources/product/product_datasource.dart`)
```

Exit 1; no machine-readable verdict anywhere.

Test-level RED (new + extended envelope tests against the unfixed command):

Command: `dart test test/plugins/datasource/datasource_check_command_test.dart`

```text
00:00 +4 -6: Some tests failed.
Failing tests:
  ... check verb — --json envelope (issue #1103) drift findings carry the full {kind, file, member, fix} shape and no human prose leaks into stdout
  ... check verb — --json envelope (issue #1103) match path emits the schema-1 envelope with empty findings
  ... check verb — negative impl @override method absent from the interface exits 1
  ... check verb — negative impl missing an interface method exits 1 naming method + file
  ... (and 2 more)

Could not find an option named "--json".   ← all 6 failures
```

## GREEN (after the fix)

Command: `dart test test/plugins/datasource/datasource_check_command_test.dart`

```text
00:00 +10: All tests passed!
```

Real CLI, drift fixture, `--json`:

```text
{"schema":1,"verdict":"drift","entity":"Product","findings":[{"kind":"missing-method","file":"lib/src/data/datasources/product/product_remote_datasource.dart","member":"getList","fix":"implementation `ProductRemoteDataSource` is missing a method declared in `ProductDataSource`"}]}
EXIT=1
```

Real CLI, drift fixture, no `--json` (human path preserved):

```text
❌ datasource check failed for `Product`: 1 parity divergence(s) between `ProductDataSource` and its implementations.
--> fix: implementation `ProductRemoteDataSource` is missing a method declared in `ProductDataSource` — method `getList`, file `lib/src/data/datasources/product/product_remote_datasource.dart` (interface: `lib/src/data/datasources/product/product_datasource.dart`)
EXIT=1
```

Real CLI, parity fixture (getList restored), `--json`:

```text
{"schema":1,"verdict":"match","entity":"Product","findings":[]}
EXIT=0
```

Real CLI, parity fixture, no `--json`:

```text
✅ datasource parity OK for `Product`: `ProductDataSource` vs lib/src/data/datasources/product/product_remote_datasource.dart — all public methods at parity.
EXIT=0
```

## Red/green discrimination re-proof (final test code)

Command: `git stash push lib/src/commands/datasource_check_command.dart` →
`dart test test/plugins/datasource/datasource_check_command_test.dart`

```text
00:00 +4 -6: Some tests failed.   (6 × "Could not find an option named \"--json\"")
```

`git stash pop` → run → `00:00 +10: All tests passed!`

## Refactor

None required; the parity-gate detection loop is byte-identical to the
pre-fix tree — only the emission layer branches on `jsonMode`.
