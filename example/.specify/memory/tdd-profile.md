# TDD Profile — example (Flutter target)

The example app is a Flutter project: the skin lane's widget tests run
on the flutter runner.

## Stack

- **Language**: Dart 3.13 (Flutter 3.47 stable).
- **Test runner**: `flutter_test`.
- **Static analysis**: `flutter analyze` from this directory.

## Commands

- Single test: `flutter test {file} --plain-name "{name}"` (the `--plain-name` filter matches test names containing the string).
- Whole file: `flutter test {file}`
- Full suite: `flutter test`

## Keys (machine-readable)

```yaml
runner: flutter_test
single: 'flutter test {file} --plain-name "{name}"'
file: 'flutter test {file}'
suite: 'flutter test'
coverage: 'flutter test --coverage'
```
