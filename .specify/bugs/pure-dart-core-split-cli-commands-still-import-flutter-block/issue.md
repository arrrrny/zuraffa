# Bug Issue: Pure-Dart Core Split: CLI commands still import Flutter (blocks A2)

- **Slug**: pure-dart-core-split-cli-commands-still-import-flutter-block
- **Fetched**: 2026-08-27T14:26:42.986858+00:00
- **Issue**: 495
- **URL**: https://github.com/arrrrny/zuraffa/issues/495
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

# Bug Assessment: Pure-Dart Core Split - CLI Commands Still Import Flutter

**Feature**: `014-pure-dart-core-split` (#253)
**Bug ID**: `014-pure-dart-core-split-cli-flutter-imports`
**Date**: 2026-08-26
**Base Commit**: `614e648`

---

## Summary

The Pure-Dart Core Split feature (#253) requires **zero `package:flutter/` imports** in `zuraffa/lib/` and `zuraffa/bin/`. While the core leaks (api_bridge, failure_handler, background_usecase, locale_converter) have been fixed, two CLI command files still directly import Flutter:

1. `lib/src/commands/create_command.dart` - imports `package:flutter/material.dart` (line 1)
2. `lib/src/commands/module_command.dart` - imports `package:flutter/material.dart` (line 1)

These imports are used **only in string templates** for generated Flutter code, but the import itself violates the "zero Flutter imports" acceptance criterion (A2).

---

## Expected Behavior

Per spec.md acceptance criteria:
> - [x] Zero `package:flutter/` imports in `zuraffa/lib/` and `zuraffa/bin/`

The CLI commands should generate Flutter code as **string constants** without importing Flutter types in the command implementation itself.

---

## Actual Behavior

Two files in `lib/src/commands/` contain direct Flutter imports:

### 1. `lib/src/commands/create_command.dart:1`
```dart
import 'package:flutter/material.dart';
```
Used in string templates for `_viewContent`, `_controllerContent`, `_presenterContent` methods that generate Flutter page files.

### 2. `lib/src/commands/module_command.dart:1`
```dart
import 'package:flutter/material.dart';
```
Used in `_writePlaceholderFiles` method to generate a Flutter feature plugin scaffold.

Both files are in `lib/src/commands/`, which is part of the **core pure-Dart package** (`zuraffa`). They must not import Flutter.

---

## Root Cause

The CLI commands were written when the entire project was Flutter-first. They generate Flutter code as string templates and imported Flutter types directly in the command file rather than using string constants.

The `module_command.dart` is particularly problematic because it generates a **Flutter feature package** scaffold (which is correct behavior), but it does so by importing Flutter in the command itself.

---

## Impact

- **Acceptance Criterion A2 fails**: `dart analyze lib bin` passes (no static errors because the imports are valid), but the grep check for Flutter imports fails.
- **Acceptance Criterion A6 partially affected**: CLI commands work but violate pure-Dart constraint.
- **Unit Behavior U21 fails**: `zfa` CLI does not import Flutter in its own code.

---

## Reproduction Steps

```bash
# Check for Flutter imports in core package
grep -r "^import 'package:flutter" lib/src/ bin/ --include="*.dart"
# Returns:
# lib/src/commands/create_command.dart:import 'package:flutter/material.dart';
# lib/src/commands/module_command.dart:import 'package:flutter/material.dart';

# Run dart analyze (passes, but doesn't catch this architectural violation)
dart analyze lib bin
```

---

## Fix Strategy

### For `create_command.dart`:
Replace the Flutter import with string constants:
```dart
// Before
import 'package:flutter/material.dart';

// After - use string constants
const _flutterMaterialImport = "import 'package:flutter/material.dart';";
const _zuraffaImport = "import 'package:zuraffa/zuraffa.dart';";
const _zuraffaFlutterImport = "import 'package:zuraffa_flutter/zuraffa_flutter.dart';";
```

Then use these constants in the generated string templates.

### For `module_command.dart`:
Similarly, replace the Flutter import with string constants for the generated plugin scaffold. The command generates a Flutter package scaffold, so the generated code SHOULD have Flutter imports - but the command itself (running in pure-Dart zuraffa) should not.

```dart
// Before
import 'package:flutter/material.dart';

// After
const _flutterMaterialImport = "import 'package:flutter/material.dart';";
const _zuraffaFlutterImport = "import 'package:zuraffa_flutter/zuraffa_flutter.dart';";
```

---

## Affected Files

| File | Lines | Fix Type |
|------|-------|----------|
| `lib/src/commands/create_command.dart` | 1, 143, 173, 193 | Replace import with string constants |
| `lib/src/commands/module_command.dart` | 1, 173, 174 | Replace import with string constants |

---

## Test Coverage

**Existing tests**: None found for these specific CLI commands (`create_command_test.dart`, `module_command_test.dart` do not exist).

**Required tests**:
1. Unit test verifying `create_command.dart` has no Flutter imports
2. Unit test verifying `module_command.dart` has no Flutter imports
3. Integration test: `zfa create --page test_page` works and generates valid Flutter code
4. Integration test: `zfa module TestFeature` works and generates valid Flutter feature package

---

## Verification

After fix:
```bash
# Should return empty (no Flutter imports)
grep -r "^import 'package:flutter" lib/src/commands/ --include="*.dart"

# dart analyze should still pass
dart analyze lib bin

# CLI commands should still function
dart run bin/zuraffa.dart create --page test_page
dart run bin/zuraffa.dart module TestFeature --dry-run
```

---

## Severity

**Medium** - Blocks acceptance criterion A2 and U21. Does not break functionality but violates the pure-Dart architecture contract.

---

## Related Issues

- Feature #253: Pure-Dart Core Split
- Spec: `/Users/ahmettok/Developer/zuraffa/specs/014-pure-dart-core-split/spec.md`
- Test list: `/Users/ahmettok/Developer/zuraffa/specs/014-pure-dart-core-split/tdd/test-list.md` (behaviors A2, A6, U21)

---

## Recommended Fix Order

1. Fix `create_command.dart` - simpler, only generates page files
2. Fix `module_command.dart` - generates full feature package scaffold
3. Add unit tests for both
4. Run integration verification

## Comments

None.
