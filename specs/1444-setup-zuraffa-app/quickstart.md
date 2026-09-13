# Quickstart: Setup generates ZuraffaApp as root widget

## Prerequisites

- `zfa` CLI available on PATH (or run from repo root via `dart run`)
- Flutter SDK installed
- `zuraffa_ui` package available (published or path dependency)

## Validation Scenarios

### Scenario 1: Fresh Flutter app uses ZuraffaApp

```bash
# Create a temp directory and run setup
cd /tmp
zfa setup test_app

# Verify main.dart uses ZuraffaApp
grep -q "ZuraffaApp" test_app/lib/main.dart && echo "PASS" || echo "FAIL"

# Verify zuraffa_ui is imported
grep -q "zuraffa_ui" test_app/lib/main.dart && echo "PASS" || echo "FAIL"

# Verify debugShowCheckedModeBanner is false
grep -q "debugShowCheckedModeBanner: false" test_app/lib/main.dart && echo "PASS" || echo "FAIL"
```

**Expected**: `main.dart` contains `ZuraffaApp(...)` with title, debugShowCheckedModeBanner: false, and zuraffa_ui import.

### Scenario 2: Pure Dart setup has no app shell

```bash
cd /tmp
zfa setup test_dart_lib --dart

# Verify no main.dart with ZuraffaApp
! grep -q "ZuraffaApp" test_dart_lib/lib/main.dart 2>/dev/null && echo "PASS" || echo "FAIL"
```

**Expected**: No Flutter app shell generated.

### Scenario 3: Existing app upgrades via --zuraffa-app

```bash
# On an existing Flutter project with MaterialApp.router
zfa app shell --zuraffa-app --force

grep -q "ZuraffaApp" lib/main.dart && echo "PASS" || echo "FAIL"
```

**Expected**: `my_app.dart` uses `ZuraffaApp`.

### Scenario 4: Backward compatibility — no flag keeps MaterialApp.router

```bash
zfa app shell --force

grep -q "MaterialApp" lib/src/app/my_app.dart && echo "PASS" || echo "FAIL"
```

**Expected**: `MaterialApp.router` preserved when `--zuraffa-app` is not passed.

### Scenario 5: Missing zuraffa_ui refuses with error

```bash
# On a Flutter project WITHOUT zuraffa_ui in pubspec
zfa app shell --zuraffa-app --force 2>&1

# Should print error about missing zuraffa_ui
```

**Expected**: Clear error message: "pubspec.yaml does not declare zuraffa_ui".

## Related Artifacts

- Spec: [spec.md](./spec.md)
- Data model: [data-model.md](./data-model.md)
- Research: [research.md](./research.md)
