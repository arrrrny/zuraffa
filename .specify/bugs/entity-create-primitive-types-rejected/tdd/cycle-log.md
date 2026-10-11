# TDD Cycle Log — issue #1270 (entity create primitive types)

Branch: `fix/1270-entity-create-primitive-types-rejected` (base d3679e0f)

## C1 — RED: `Boolean` alias rejected by entity create (the issue repro)

Command: `dart test test/commands/entity_create_primitive_types_test.dart`

New suite (5 CLI-level tests, unit group withheld — see note): **`+2 -3: Some tests failed.`**

The 3 failures fail for the RIGHT reason — the issue #1270 signature, verbatim:

```
Expected: <0>
  Actual: <1>
  • Unknown type "Boolean" for field "isLoading" — no matching entity directory or enum file found under lib/src/domain/entities.
```

also for `hasError:Boolean` (repro test), and for `flags:List<Boolean>` /
`maybe:Boolean?` / `rate:Map<String, Boolean>` (alias-forms test), and
`add-field --field done:Boolean` (shared parse path test).

Real-CLI red evidence (manual, pre-fix, sandbox project):

```
$ zfa entity create -n Login --field isLoading:Boolean --field hasError:Boolean
❌ Cannot create entity "Login": field type(s) could not be resolved.
  • Unknown type "Boolean" for field "isLoading" — no matching entity directory
    or enum file found under lib/src/domain/entities.
  • Unknown type "Boolean" for field "hasError" — no matching entity directory
    or enum file found under lib/src/domain/entities.
EXIT=1
```

Note (methodology): the unit group for
`EntityUtils.normalizePrimitiveTypeAliases` was temporarily withheld during
the RED run because the API does not exist pre-fix; including it fails the
file at COMPILE time, which masks the behavioral red (the playbook allows an
unresolved-symbol red only with a stub+re-run). The behavioral red above is
the recorded red. The unit group ships in the committed file and is green
post-fix.

Also recorded: the 2 RED-phase PASSING tests pin already-correct behavior —
`bool`/`int`/`double`/`String`/`num` spellings already resolve and emit
inline (`+2`), and the custom-type rejection (`Product` with no entity dir)
still exits non-zero.

## C1 — GREEN: minimal fix

Fix (2 files, +45/-1):
- `lib/src/utils/entity_utils.dart` — new `EntityUtils.normalizePrimitiveTypeAliases(String)`: rewrites the `boolean` token case-insensitively at word boundaries to the built-in `bool` inside a field type expression; nothing else.
- `lib/src/commands/entity_command.dart` — `_parseFields` (the shared type-resolution entry for `entity create` / `entity add-field`) normalizes the parsed field TYPE via `parsed.copyWith(type: ...)`. Names and JSON wire names untouched; non-primitive resolution untouched.

Full committed suite: **`00:38 +8: All tests passed!`** (5 CLI-level + 3 unit)

Real-CLI green evidence (fresh sandbox, post-restore):

```
$ zfa entity create -n Login --field isLoading:Boolean --field hasError:Boolean
✓ Created entity: lib/src/domain/entities/login/login.dart
✨ Generated 2 fields:
  - isLoading: bool
  - hasError: bool
EXIT=0
$ grep "get" lib/src/domain/entities/login/login.dart
  bool get isLoading;
  bool get hasError;
```

No refactor needed: the smallest sufficient change shipped in C1 (a pure
function + one call site). No behavior-preserving cleanup was left on the
table; formatter/analyzer pass clean.
