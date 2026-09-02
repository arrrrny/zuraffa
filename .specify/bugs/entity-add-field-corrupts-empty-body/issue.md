# Bug Issue: entity add-field corrupts empty-body entities — fields inserted above file header/class declaration, invalid Dart

- **Slug**: entity-add-field-corrupts-empty-body
- **Fetched**: 2026-09-02
- **Issue**: 759
- **URL**: https://github.com/arrrrny/zuraffa/issues/759
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa entity add-field -n <Name> --field <name>:<Type> ...` on an entity created field-less (the tdd cycle's default: `zfa entity create -n Todo`).

## What was expected

The field getter(s) should be inserted inside the entity class body, keeping the file valid Dart.

## What returned

The field getters are prepended at byte 0 — ABOVE the file header, imports, and class declaration — producing invalid Dart. `build_runner` then fails with `A function body must be provided` errors.

Example corrupted shape (top of file):

```dart
String get id;
String get title;
// ... above the original header/imports/class declaration
abstract class $Todo {}
```

## Root cause

zorphy 2.3.1, `EntityCreator._insertFields`:

```dart
final classPattern = RegExp(r'abstract class \$+' + className + r'\s*\{');
final classMatch = classPattern.firstMatch(content);
...
if (allMatches.isEmpty) {
  insertPosition = content.indexOf('{', classMatch.end) + 1;
}
```

The regex match already consumes the class's opening `{`, so `indexOf('{', ...)` searches for a *second* brace. For an empty same-line body (`abstract class $Todo {}`) there is none: `indexOf` returns `-1` and `insertPosition` becomes `0`. Entities with existing multi-line fields take the `allMatches` branch and are unaffected.

## Workaround

Apply the full schema at creation time with `zfa entity create -n Todo --field ...` (template path — correct). This is what `examples/todo_tdd` does.

## Evidence

Reproduced during the end-to-end TDD cycle verification (commit `14651299`, zorphy 2.3.1, Dart 3.13.3). Full context: `REPORTS/tdd-cycle-end-to-end-verification.md` (finding F2, severity: high).

## Comments

None.
