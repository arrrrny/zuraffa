// Fast-tier test for the `zfa tdd run specs/<feature>` path-format
// feature argument (the canonical path format shown throughout zuraffa's
// own docs and error messages). The fix lives in
// `lib/src/plugins/tdd/commands/run_command.dart` (strips a leading
// `specs/` prefix before validation).
//
// The full driver-level path is exercised by the slow-tier
// `test/plugins/tdd/run_command_test.dart` suite. This fast file
// exercises the same fix surface against a directly-invoked command
// runner with a minimal feature directory.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/commands/run_command.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

void main() {
  late Directory tmpRoot;
  late Directory specsDir;
  const feature = '900-path-format-test';

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('tdd_run_path_fmt_');
    specsDir = Directory(p.join(tmpRoot.path, 'specs', feature))
      ..createSync(recursive: true);
    // Minimal test list so list-read doesn't fail.
    File(p.join(specsDir.path, 'tdd', 'test-list.md'))
        .createSync(recursive: true);
  });

  tearDown(() {
    if (tmpRoot.existsSync()) tmpRoot.deleteSync(recursive: true);
  });

  /// Drive the RunCommand with the given positional feature argument
  /// and capture thrown exceptions. Returns the parsed exit behavior.
  Future<Object?> drivePositional(String positionalFeature) async {
    final plugin = TddPlugin();
    // The RunCommand takes a TddPlugin; we never reach the run() body
    // because the path-format fix is applied before run() executes
    // its first real step.
    final cmd = RunCommand(plugin);
    final runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(cmd);
    try {
      await runner.run([
        'run',
        positionalFeature,
        '--project',
        tmpRoot.path,
      ]);
      return null;
    } catch (e) {
      return e;
    }
  }

  test('path-format arg `specs/<feature>` is accepted (no UsageException)',
      () async {
    final result = await drivePositional('specs/$feature');
    // We expect either null (full success, which would require the
    // fake zfa to be set up) or a non-UsageException error. The point
    // is: NOT a `UsageException` saying "expected a single spec
    // directory name, not a path".
    if (result != null) {
      expect(
        result.toString(),
        isNot(contains('expected a single spec directory name')),
        reason: 'specs/ prefix should be stripped before validation, '
            'got: $result',
      );
    }
  });

  test('bare-name feature arg still works (no regression)', () async {
    final result = await drivePositional(feature);
    if (result != null) {
      expect(
        result.toString(),
        isNot(contains('expected a single spec directory name')),
        reason: 'bare name should be accepted, got: $result',
      );
    }
  });

  test('path-format arg `specs/../foo` is still rejected (traversal guard)',
      () async {
    final result = await drivePositional('specs/../foo');
    // After stripping `specs/`, the remainder is `../foo`, which
    // fails the segment check (contains `/`). The error message names
    // the original input.
    expect(
      result,
      isNotNull,
      reason: 'specs/../foo must be rejected',
    );
    expect(
      result.toString(),
      contains('invalid feature'),
      reason: 'expected UsageException, got: $result',
    );
  });

  test('bare `..` is still rejected (traversal guard)', () async {
    final result = await drivePositional('..');
    expect(result, isNotNull);
    expect(result.toString(), contains('invalid feature'));
  });

  test('bare `specs/` is left as-is and treated as a literal feature name',
      () async {
    // `_stripSpecsPrefix` keeps the original `specs/` when the suffix
    // is empty (it would otherwise be an empty string, which is not a
    // valid feature). The segment check then rejects it.
    final result = await drivePositional('specs/');
    expect(result, isNotNull);
    expect(result.toString(), contains('invalid feature'));
  });
}
