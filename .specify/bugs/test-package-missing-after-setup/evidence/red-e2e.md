# RED evidence (e2e) — captured 2026-09-01T18:06:57Z

## generated pubspec dev_dependencies (zfa v6.1.0 source, fresh project)
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.16.0
  json_serializable: ^6.14.1

  mocktail: ^1.0.0
  coverage: ^1.6.0
  mutation_test: ^1.0.0
flutter:
```

## grep test:
CONFIRMED BUG: 'test' NOT in dev_dependencies

## flutter test test/tdd/a1_test.dart
```
Error: Couldn't resolve the package 'test' in 'package:test/test.dart'.
test/tdd/a1_test.dart:16:8: Error: Not found: 'package:test/test.dart'
test/tdd/a1_test.dart:30:28: Error: Method not found: 'isA'.
      expect(result, isNot(isA<UnimplementedError>()));
test/tdd/a1_test.dart:30:22: Error: Method not found: 'isNot'.
      expect(result, isNot(isA<UnimplementedError>()));
test/tdd/a1_test.dart:30:7: Error: Method not found: 'expect'.
      expect(result, isNot(isA<UnimplementedError>()));
```
