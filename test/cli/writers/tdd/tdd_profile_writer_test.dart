// Tests for the TddProfileWriter (spec 041-tdd-setup-plugin, U10-U11).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/tdd_profile_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tdd_profile_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('writes the five-key profile to .specify/memory/tdd-profile.md',
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
  });

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
    expect(
      () => writer.write(tmpDir.path),
      throwsA(isA<StateError>()),
    );
  });
}
