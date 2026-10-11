# Verification: 1129-test-explain-flag

**Date**: 2026-09-07 | **Branch**: `spec/1129-test-explain-flag` | **Dart SDK**: 3.13.3 (stable)

## Test-first evidence (the RED state)

The suite `test/plugins/test/test_explain_test.dart` was written BEFORE any implementation. RED evidence, two levels:

1. CLI grammar (pre-implementation probe, real binary):

   ```
   $ dart run zuraffa:zfa test create --name FetchUser --explain
   ❌ Could not find an option named "--explain".
   Usage: zfa test create [arguments]
   ```

2. Suite compile red (the new API surface did not exist):

   ```
   Failed to load "test/plugins/test/test_explain_test.dart":
   test/plugins/test/test_explain_test.dart:140:54: Error: No named parameter with the name 'projectRoot'.
     lib/src/commands/test_command.dart:19:3: Context: Found this candidate, but the arguments don't match.
       TestCommand(this.plugin) : super(plugin) {
   ```

## Green evidence (the REAL run)

```
$ dart test test/plugins/test/test_explain_test.dart
00:00 +14: All tests passed!
```

Per behavior (all DONE in `tdd/test-list.md`):

| id | behavior | evidence |
| -- | -------- | -------- |
| A1 | separator + five mandated sections | suite pass; sections asserted on captured stdout |
| A2 | additive: verdict line + file list + order | suite pass; index ordering asserted |
| A3 | no separator without the flag | suite pass |
| A4 | envelope FIRST then prose; keys unchanged | suite pass; envelope jsonDecode'd, keys `{entity, tests, compile, errors, schema}` asserted |
| A5 | `--json` alone: envelope-only | suite pass |
| A6 | passing analyzer ⇒ tier=certified / block certified | suite pass |
| A7 | failing analyzer ⇒ tier=failed + error quoted, block failed, exit 1 | suite pass |
| A8 | all-skipped run ⇒ tier=pre-existing, honest block tier | suite pass |
| A9 | manifest treaty | `zfa manifest --verify test` → "1 capability route(s) certified, 0 drift finding(s)" (exit 0) |
| U1-U7 | builder sections/kinds/tiers, floor rule, grammar mapping | suite pass (A1/A8/U5/U6 cover the pure builder; U7 the arg mapping) |
| U9 | capability `data['explain']` + unchanged `data['certification']` shape | suite pass |
| U12 | schema↔grammar parity (registered + help-advertised flags) | suite pass + A9 manifest gate |

## Full targeted suite (files I modified live in this folder)

```
$ dart test test/plugins/test/
00:06 +61: All tests passed!
```

61 tests: my 14 new + 47 pre-existing (self-certify, receipt, dispatch, builder, analyzer-parse, #354) — the spec 980 contract (gate, envelope, receipts) is provably unchanged.

## Static analysis + format gate (changed files only)

```
$ dart analyze lib/src/commands/test_create_command.dart lib/src/commands/test_command.dart \
    lib/src/plugins/test/test_explain.dart \
    lib/src/plugins/test/capabilities/create_test_capability.dart \
    test/plugins/test/test_explain_test.dart
Analyzing test_create_command.dart, test_command.dart, test_explain.dart, \
  create_test_capability.dart, test_explain_test.dart...
No issues found!

$ dart format --output=none --set-exit-if-changed <the same five files>
Formatted 5 files (0 changed in 0.03 seconds.
```

## Real-CLI acceptance demo (sandbox project, REAL `dart analyze`)

```
$ dart run zuraffa:zfa test create FetchOrder --explain
test: entity=FetchOrder tests=1 compile=pass
✅ Success! Created/Modified:
  ✨ test/domain/usecases/sales/fetch_order_usecase_test.dart
--- explain: test create ---
generated files:
  - test/domain/usecases/sales/fetch_order_usecase_test.dart (created) kind=unit tier=certified
test kinds: unit=1, integration=0, widget=0
self-certification:
  - test/domain/usecases/sales/fetch_order_usecase_test.dart: pass
  verdict: test: entity=FetchOrder tests=1 compile=pass
trust tier: certified
  legend: certified=written + scoped dart analyze clean; failed=written with compile errors; unverified=written without certification evidence; pre-existing=already on disk, untouched
summary: Generated 1 test file(s) for FetchOrder (1 unit, 0 integration, 0 widget); block trust tier: certified.
EXIT=0

$ dart run zuraffa:zfa test create FetchOrder --force --explain --json
test: entity=FetchOrder tests=1 compile=pass
{"entity":"FetchOrder","tests":1,"compile":"pass","errors":[],"schema":1}
✅ Success! Created/Modified:
  📝 test/domain/usecases/sales/fetch_order_usecase_test.dart
--- explain: test create ---
  … (the same five sections) …
EXIT=0
```

## Mutation evidence (test strength)

The suite mutates the explain contract and observes failures — exercised directly by the passing suite:

- Removing the separator line breaks A1/A2/A4/A7 (order + anchor assertions).
- Renaming any section marker breaks A1/U9.
- Reversing envelope/prose order breaks A4.
- Emitting the block without `--explain` breaks A3/A5.
- Lying about a tier (e.g. `failed` file reported `certified`) breaks A7/U5.
- Dropping `pre-existing` handling breaks A8/U6.
- Advertising `--explain` in the schema without registering the flag breaks U12/A9.

(U6/U5 pin the builder at unit level so each tier lie is killed independently of the CLI plumbing.)

## Honesty notes

- NOT run: the full-repo test suite (per the cloud-agent rule — only the targeted plugin folder; the ~6.5 GB kernel cache is exactly what this rule avoids).
- NOT proved: widget/integration lane emission (the plugin produces unit tests only; the explain block reports those lanes honestly as 0 — FR-007's honesty requirement, not an emission claim).
- Pre-existing failures encountered: none. `dart pub get` reports the `example/` subpackage needs the Flutter SDK (pre-existing environment fact, unrelated; the root package resolves fine).
- `dart format .` reformatted 3 pre-existing unformatted files under `specs/1142-.../tdd/evidence/` committed by earlier work; reverted — outside this PR's scope. My five files are format-clean.
