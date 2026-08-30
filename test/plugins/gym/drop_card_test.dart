@Tags(['slow'])

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// NOTE: We test the DropCard helper defined under `.gym/lib/drop_card.dart`
// (not under `lib/src/`). The `.gym/lib/` directory is part of the GYM
// exercise infrastructure; the helper is imported by exercise scripts
// that run via `dart run .gym/exercise-*.dart`.
//
// To test it, we run small Dart scripts via `dart run` that import the
// file by absolute path and exercise its API.

void main() {
  final repoRoot = _findRepoRoot();
  final dropCardFile = File(p.join(repoRoot, '.gym', 'lib', 'drop_card.dart'));

  group('DropCard contract (B01, B02, B03, B15)', () {
    test('drop_card.dart file exists', () {
      expect(
        dropCardFile.existsSync(),
        isTrue,
        reason: '.gym/lib/drop_card.dart must exist',
      );
    });

    test('file declares the DropCard class with all four required fields', () {
      final src = dropCardFile.readAsStringSync();
      expect(src, contains('class DropCard'));
      expect(src, contains('final String did'));
      expect(src, contains('final String expected'));
      expect(src, contains('final String happened'));
      expect(src, contains('final String where'));
    });

    test('constructor validates all four fields are non-empty (B02)', () {
      final src = dropCardFile.readAsStringSync();
      expect(src, contains("if (did.isEmpty)"));
      expect(src, contains("if (expected.isEmpty)"));
      expect(src, contains("if (happened.isEmpty)"));
      expect(src, contains("if (where.isEmpty)"));
      expect(src, contains('ArgumentError'));
    });

    test('emit() produces markdown with all four fields (B01)', () {
      final result = _runDartScript('''
import '${dropCardFile.path}';

void main() {
  final card = DropCard(
    exerciseId: 'test-exercise',
    did: 'do something',
    expected: 'expected outcome',
    happened: 'actual outcome',
    where: 'stage-1',
  );
  print(card.emit());
}
''');
      expect(result.exitCode, equals(0), reason: 'stderr: ${result.stderr}');
      final out = result.stdout;
      expect(out, contains('# DROP CARD — test-exercise'));
      expect(out, contains('**Did**: do something'));
      expect(out, contains('**Expected**: expected outcome'));
      expect(out, contains('**Happened**: actual outcome'));
      expect(out, contains('**Where**: stage-1'));
    });

    test('constructor throws ArgumentError when Did is empty (B02)', () {
      final result = _runDartScript('''
import '${dropCardFile.path}';

void main() {
  try {
    DropCard(
      exerciseId: 'test',
      did: '',
      expected: 'e',
      happened: 'h',
      where: 'w',
    );
    print('NO_THROW');
  } catch (e) {
    print('THREW: \$e');
    print('TYPE: \${e.runtimeType}');
  }
}
''');
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('THREW'));
      // ArgumentError's toString is "Invalid argument(s): ..." — check
      // either the runtime type name or the message.
      expect(
        result.stdout.contains('ArgumentError') ||
            result.stdout.contains('Invalid argument') ||
            result.stdout.contains('did must not be empty'),
        isTrue,
        reason: 'Expected an ArgumentError-like message; got: ${result.stdout}',
      );
    });

    test('constructor throws ArgumentError when Where is empty (B02)', () {
      final result = _runDartScript('''
import '${dropCardFile.path}';

void main() {
  try {
    DropCard(
      exerciseId: 'test',
      did: 'd',
      expected: 'e',
      happened: 'h',
      where: '',
    );
    print('NO_THROW');
  } catch (e) {
    print('THREW: \$e');
    print('TYPE: \${e.runtimeType}');
  }
}
''');
      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('THREW'));
      expect(
        result.stdout.contains('ArgumentError') ||
            result.stdout.contains('Invalid argument') ||
            result.stdout.contains('where must not be empty'),
        isTrue,
        reason: 'Expected an ArgumentError-like message; got: ${result.stdout}',
      );
    });

    test('writeTo() persists the card to a file (B03)', () {
      final tmpDir = Directory.systemTemp.createTempSync('dropcard_test_');
      try {
        final outFile = p.join(tmpDir.path, 'nested', 'DROP_CARD.md');
        final result = _runDartScript('''
import 'dart:io';
import '${dropCardFile.path}';

void main() {
  final card = DropCard(
    exerciseId: 'persist-test',
    did: 'd',
    expected: 'e',
    happened: 'h',
    where: 'w',
  );
  final out = card.writeTo(File('$outFile'));
  print(out);
}
''');
        expect(result.exitCode, equals(0), reason: 'stderr: ${result.stderr}');
        final card = File(outFile);
        expect(card.existsSync(), isTrue);
        final content = card.readAsStringSync();
        expect(content, contains('**Did**: d'));
        expect(content, contains('**Where**: w'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('emitAndPersist writes file AND prints to stderr (B15)', () {
      final tmpDir = Directory.systemTemp.createTempSync('dropcard_persist_');
      try {
        final result = _runDartScript('''
import 'dart:io';
import '${dropCardFile.path}';

void main() {
  final card = DropCard(
    exerciseId: 'persist-stderr-test',
    did: 'attempted X',
    expected: 'Y',
    happened: 'Z',
    where: 'spawn: try-do-x',
  );
  card.emitAndPersist('${tmpDir.path}');
}
''');
        expect(result.exitCode, equals(0), reason: 'stderr: ${result.stderr}');
        // File persisted.
        final card = File(p.join(tmpDir.path, 'DROP_CARD.md'));
        expect(card.existsSync(), isTrue);
        // stderr got the rendered card.
        expect(result.stderr, contains('DROP CARD'));
        expect(result.stderr, contains('spawn: try-do-x'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });
  });
}

_ProcessResult _runDartScript(String source) {
  final tmpDir = Directory.systemTemp.createTempSync('dropcard_run_');
  final tmp = File(p.join(tmpDir.path, 'run.dart'));
  try {
    tmp.writeAsStringSync(source);
    final result = Process.runSync('dart', ['run', tmp.path]);
    return _ProcessResult(
      result.exitCode,
      result.stdout.toString(),
      result.stderr.toString(),
    );
  } finally {
    tmpDir.deleteSync(recursive: true);
  }
}

class _ProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  _ProcessResult(this.exitCode, this.stdout, this.stderr);
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: zuraffa\n')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find zuraffa repo root');
    }
    dir = parent;
  }
}
