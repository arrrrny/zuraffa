# GitHub Issue

- URL: https://github.com/arrrrny/zuraffa/issues/1349
- Number: 1349
- Filed: 2026-09 (found during a from-scratch zfa TDD guideline walkthrough — todo app, macOS — on zfa build d23bde35)
- Title: zfa tdd init generates lib/app.dart importing zuraffa_flutter/get_it without adding the dependencies
- Severity: high (day-zero baseline is red out of the box on fresh Flutter projects)

## Report (verbatim from the issue)

### Repro

1. `flutter create --platforms=macos zfa_todo_app && cd zfa_todo_app` (Flutter 3.47.2 / Dart 3.13.2)
2. Add zfa-cycle dev_dependencies per docs (zorphy, build_runner, etc.), `flutter pub get`
3. `zfa tdd init`

### Expected

The TDD baseline init creates compiles — init prints `Run flutter test to confirm a green baseline`.

### Actual

`lib/app.dart` is generated with:

```dart
import 'package:zuraffa_flutter/zuraffa_flutter.dart';
...
final GetIt di = GetIt.instance;
```

but `zuraffa_flutter` and `get_it` are NOT added to `pubspec.yaml` dependencies. Every test fails to compile:

```
Error: Couldn't resolve the package 'zuraffa_flutter' in 'package:zuraffa_flutter/zuraffa_flutter.dart'.
lib/app.dart:25:9: Error: Type 'GetIt' not found.
```

So the day-zero baseline `zfa tdd init` promises is red out of the box on a fresh Flutter project.

### Suggested fix (from the issue)

In the Flutter branch of `zfa tdd init`, also ensure `zuraffa_flutter` and `get_it` are present in `dependencies` (same self-heal pass as the `test` dev_dependency), so the generated baseline compiles immediately after init.
