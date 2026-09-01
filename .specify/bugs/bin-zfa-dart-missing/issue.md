# Bug Issue: bin/zfa.dart still missing, zfa tdd refactor fails

- **Slug**: bin-zfa-dart-missing
- **Fetched**: 2026-09-01T17:23:21Z
- **Issue**: 717
- **URL**: https://github.com/arrrrny/zuraffa/issues/717
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**:

## Body

## Bug Description

`zfa tdd refactor` still calls `dart run bin/zfa.dart build` which does not exist after `zfa setup`. The system-level `zfa` CLI is at `~/.local/bin/zfa`, but no `bin/zfa.dart` is created in the project.

## Confirmation (v6.1.0, fresh project)

Tested on a fresh project at zfa v6.1.0.

**Result:** BUG STILL PRESENT.

```
zfa tdd refactor: applying passes
   pass: build
     command: dart run bin/zfa.dart build
     exit: 255
     changed: (none)
   pass "build" failed — misfire-stop.
```

`zfa setup` does NOT create `bin/zfa.dart` in the project. System `zfa` is at `~/.local/bin/zfa`.

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `zfa tdd verify-red A7 --feature=001-app-bootstrap`
7. `zfa tdd make A7 --feature=001-app-bootstrap`
8. `zfa tdd refactor A7 --feature=001-app-bootstrap`
   → **exit 1**: `dart run bin/zfa.dart build` fails because `bin/zfa.dart` does not exist

## Workaround

Create `bin/zfa.dart` as a passthrough to system `zfa`:

```dart
import 'dart:io';
Future<void> main(List<String> args) async {
  final result = await Process.run('/Users/ahmettok/.local/bin/zfa', args);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}
```

## Environment

- zfa version: v6.1.0
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
