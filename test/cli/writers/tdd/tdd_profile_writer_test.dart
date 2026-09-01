// Tests for the TddProfileWriter (spec 041-tdd-setup-plugin, U10-U11).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/tdd_profile_writer.dart';
import 'package:zuraffa/src/plugins/tdd/models/tdd_profile.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tdd_profile_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test(
    'writes the five-key profile to .specify/memory/tdd-profile.md',
    () async {
      final writer = const TddProfileWriter();
      final path = await writer.write(tmpDir.path);
      expect(path, isNotNull);
      final file = File(p.join(tmpDir.path, '.specify/memory/tdd-profile.md'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('runner: flutter_test'));
      expect(content, contains('single:'));
      expect(content, contains('file:'));
      expect(content, contains('suite:'));
      expect(content, contains('coverage:'));
    },
  );

  test('is idempotent — running twice returns null (no-op)', () async {
    final writer = const TddProfileWriter();
    final firstPath = await writer.write(tmpDir.path);
    expect(firstPath, isNotNull);
    final secondResult = await writer.write(tmpDir.path);
    expect(secondResult, isNull, reason: 'second write must be a no-op');
  });

  test('refuses to clobber an existing file with different content', () async {
    final dir = Directory(p.join(tmpDir.path, '.specify/memory'))
      ..createSync(recursive: true);
    final file = File(p.join(dir.path, 'tdd-profile.md'));
    file.writeAsStringSync('# Different content\n');
    final writer = const TddProfileWriter();
    expect(() => writer.write(tmpDir.path), throwsA(isA<StateError>()));
  });

  test(
    'force: true overwrites an existing file with different content',
    () async {
      final dir = Directory(p.join(tmpDir.path, '.specify/memory'))
        ..createSync(recursive: true);
      final file = File(p.join(dir.path, 'tdd-profile.md'));
      file.writeAsStringSync('# Different content\n');
      final writer = const TddProfileWriter();
      final returned = await writer.write(tmpDir.path, force: true);
      expect(returned, isNotNull);
      expect(file.readAsStringSync(), contains('runner: flutter_test'));
      expect(file.readAsStringSync(), isNot(contains('Different content')));
    },
  );

  test(
    'force: true is a no-op when existing content already matches',
    () async {
      final writer = const TddProfileWriter();
      final first = await writer.write(tmpDir.path);
      expect(first, isNotNull);
      // Second call with force: true still returns null because the
      // content is already a match (idempotency preserved).
      final second = await writer.write(tmpDir.path, force: true);
      expect(second, isNull);
    },
  );

  // ------------------------------------------------------------------
  // Issue #680 — the overwrite guard is a RUNNER-FAMILY check, not an
  // exact-content byte comparison. A valid non-Flutter (Dart) profile is
  // accepted as-is when targeting Dart; the only hard conflict is a
  // Flutter-vs-Dart flavor mismatch — in BOTH directions.
  // ------------------------------------------------------------------
  group('issue #680 — runner-family guard', () {
    void seedProfile(String content) {
      final dir = Directory(p.join(tmpDir.path, '.specify/memory'))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'tdd-profile.md')).writeAsStringSync(content);
    }

    test('accepts a valid custom Dart profile (different single:) when '
        'targeting Dart — no StateError, no overwrite (issue repro)', () async {
      seedProfile('''# TDD Profile — enriched by ecosystem detector

```yaml
runner: "package:test (^1.24.0)"
single: 'dart test -n "{name}"'
suite: 'dart test'
```
''');
      final writer = const TddProfileWriter(profile: TddProfile.dart);
      final result = await writer.write(tmpDir.path);
      expect(result, isNull, reason: 'accepted as-is (no-op)');
      final file = File(p.join(tmpDir.path, '.specify/memory/tdd-profile.md'));
      // The enriched content must survive untouched — overwriting it
      // with the preset template would lose information (issue #680).
      expect(file.readAsStringSync(), contains('package:test (^1.24.0)'));
      expect(file.readAsStringSync(), contains("dart test -n"));
    });

    test('still throws when a Flutter-runner profile exists but a Dart '
        'profile is being written (flavor conflict preserved)', () async {
      seedProfile('# TDD Profile\n\n```yaml\nrunner: flutter_test\n```\n');
      final writer = const TddProfileWriter(profile: TddProfile.dart);
      await expectLater(writer.write(tmpDir.path), throwsA(isA<StateError>()));
    });

    test('throws in the reverse direction too: a Dart-runner profile exists '
        'but a Flutter profile is being written (documented "or vice '
        'versa" contract)', () async {
      seedProfile('# TDD Profile\n\n```yaml\nrunner: dart\n```\n');
      final writer = const TddProfileWriter(profile: TddProfile.flutter);
      await expectLater(
        writer.write(tmpDir.path),
        throwsA(isA<StateError>()),
        reason:
            'silently keeping a Dart profile in a Flutter project '
            'leaves the baseline running `dart test` against Flutter '
            'tests — the cross-family guard must fire here too',
      );
    });

    test('runner family check is case-insensitive: "runner: Flutter_test" '
        'under a Dart-targeting write is a flavor conflict, not a valid '
        'Dart runner', () async {
      seedProfile('# TDD Profile\n\n```yaml\nrunner: Flutter_test\n```\n');
      final writer = const TddProfileWriter(profile: TddProfile.dart);
      await expectLater(writer.write(tmpDir.path), throwsA(isA<StateError>()));
    });

    test('an existing profile with no parseable runner still falls back to '
        'the exact-content guard (untrusted flavor → reject/force)', () async {
      seedProfile('# Different content, no runner line\n');
      final writer = const TddProfileWriter(profile: TddProfile.dart);
      await expectLater(writer.write(tmpDir.path), throwsA(isA<StateError>()));
      // --force overwrites it (unchanged behavior).
      final forced = await writer.write(tmpDir.path, force: true);
      expect(forced, isNotNull);
    });
  });
}
