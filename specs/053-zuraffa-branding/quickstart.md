# Quickstart: Zuraffa Branding for Generated Apps

Validate that Zuraffa branding works end-to-end after implementation.

## Prerequisites

- Flutter SDK installed (`flutter --version`)
- Dart SDK installed (`dart --version`)
- zuraffa CLI built: `dart run bin/zuraffa.dart --version`
- Brand assets present at `assets/zuraffa_app_icons/`

## Validation Scenarios

### Scenario 1: Flutter App Created with Branding

**Setup**: Use a temporary directory for the test project.

```bash
cd /tmp
rm -rf test_zuraffa_flutter_app
# Run zfa setup with branding
dart run /path/to/zuraffa/bin/zuraffa.dart setup test_zuraffa_flutter_app --flutter
```

**Verify**:
- [ ] `test_zuraffa_flutter_app/assets/zuraffa_app_icons/` exists and contains icon files
- [ ] `test_zuraffa_flutter_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/` contains Zuraffa icons (not Flutter defaults)
- [ ] `test_zuraffa_flutter_app/android/app/src/main/res/mipmap-*/ic_launcher.png` are Zuraffa giraffe icons
- [ ] `test_zuraffa_flutter_app/pubspec.yaml` includes `assets/zuraffa_app_icons/` in the assets declaration
- [ ] `test_zuraffa_flutter_app/README.md` contains "Zuraffa" in the first 10 lines
- [ ] No `flutter.png`, `flutter_animated.png`, or `FlutterLogo` references exist anywhere

### Scenario 2: Dart CLI Package Created with Branding

**Setup**: Use a temporary directory.

```bash
cd /tmp
rm -rf test_zuraffa_dart_pkg
dart run /path/to/zuraffa/bin/zuraffa.dart setup test_zuraffa_dart_pkg --dart
```

**Verify**:
- [ ] `test_zuraffa_dart_pkg/assets/zuraffa_app_icons/` exists with brand assets
- [ ] `test_zuraffa_dart_pkg/README.md` contains Zuraffa branding
- [ ] No `dart` logo references in README or assets

### Scenario 3: Idempotency (re-running on already-branded app)

```bash
cd /tmp/test_zuraffa_flutter_app
dart run /path/to/zuraffa/bin/zuraffa.dart setup test_zuraffa_flutter_app --flutter --force
```

**Verify**:
- [ ] Command completes without error
- [ ] No duplicate asset files created

## Run Commands

```bash
# Build the CLI (from zuraffa repo root)
dart run bin/zuraffa.dart setup my_branded_app --flutter --dry-run

# Run unit tests for the branding module
dart test test/core/branding/

# Full integration test (manual)
cd /tmp && rm -rf branded_test && dart run ~/Developer/zuraffa/bin/zuraffa.dart setup branded_test --flutter && echo "PASS: Branding applied"
```
