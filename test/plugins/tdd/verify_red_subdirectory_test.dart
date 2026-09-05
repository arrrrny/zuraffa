// Tests for bug #679: TDD sub-commands auto-detect the project root via
// ProjectRoot.find() when `--project` is omitted, so they work from a
// SUBDIRECTORY of the target project (walking up to the nearest
// pubspec.yaml) instead of resolving the subdirectory as the root.
//
// Hermetic by construction (issue #506 pattern): the CLI runs as a real
// SUBPROCESS whose CWD is the fixture subdirectory — the exact real-world
// scenario of the bug (a user running `zfa tdd …` from `lib/`). No
// process-global Directory.current mutation ever happens in this test
// process, so it cannot race other test files the way the in-process
// CliRunner + cwd-rewrite variant did (that variant contaminated
// test_list_reader_test.dart's repo-relative fixture reads under parallel
// `dart test` and was rejected during development of this fix).
// Slow tier: spawns real `dart test` / zfa-pipeline subprocesses whose wall
// time on constrained CI runners exceeds the fast-tier budget (and whose
// verdicts depend on runner load, not product behavior).
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/project_root.dart';

import '../../helpers/run_zfa_source.dart';
import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUpAll(initZfaSourceBin);

  setUp(() async {
    fx = await TddFixture.create();
    await fx.registerBehavior(id: 'B-001', description: 'returns 42');
    // verify-red executes the recorded test through the real `dart test`
    // runner inside the fixture, which needs the fixture's package config.
    await Process.run('dart', ['pub', 'get'], workingDirectory: fx.root.path);
  });

  tearDown(() {
    fx.dispose();
  });

  test('verify-red resolves the project root from a subdirectory without '
      '--project (bug #679)', () async {
    final subdir = p.join(fx.root.path, 'lib');
    Directory(subdir).createSync(recursive: true);
    // Pre-fix this invocation bailed with "unknown behavior id B-001"
    // + classification=unresolved, because cwd was <root>/lib and no
    // specs/<feature>/tdd/artifacts.json existed under it.
    final result = await runZfaSource([
      'tdd',
      'verify-red',
      'B-001',
      '--feature',
      fx.featureName,
    ], workingDirectory: subdir);
    final out = combinedOutput(result);
    expect(out, contains('behavior=B-001'));
    expect(out, contains('certified=true'));
    expect(
      out,
      isNot(contains('unresolved')),
      reason: 'the registry must resolve via the walked-up root',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('init ensures the baseline in the walked-up root, not the subdirectory '
      '(bug #679)', () async {
    // A dedicated fixture WITHOUT a pre-written profile: `tdd init` must
    // create the baseline itself, and the TddFixture profile template
    // would trip the (pre-#680-fix) exact-content guard in
    // TddProfileWriter — an unrelated failure mode.
    final bare = await TddFixture.create(writeProfile: false);
    final subdir = p.join(bare.root.path, 'lib', 'src');
    Directory(subdir).createSync(recursive: true);
    try {
      await runZfaSource(['tdd', 'init'], workingDirectory: subdir);
      // init reports progress via stdout.writeln, captured by the
      // subprocess runner; the contract is also asserted through the
      // files it writes (file-based style mirrors
      // tdd_command_smoke_test.dart).
      expect(
        File(p.join(bare.root.path, 'dart_test.yaml')).existsSync(),
        isTrue,
        reason:
            'dart_test.yaml must be created at the pubspec.yaml root, '
            'never in the lib/src subdirectory the command was '
            'invoked from',
      );
      expect(
        File(
          p.join(bare.root.path, '.specify/memory/tdd-profile.md'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(subdir, 'dart_test.yaml')).existsSync(),
        isFalse,
        reason: 'nothing may be written into the subdirectory',
      );
    } finally {
      bare.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('an explicit --project still overrides the auto-detected root '
      '(bug #679 regression guard)', () async {
    final other = Directory.systemTemp.createTempSync('tdd_679_override_');
    // The pubspec patcher requires a pubspec.yaml at the explicit root.
    File(p.join(other.path, 'pubspec.yaml')).writeAsStringSync('''
name: tdd_679_override
environment:
  sdk: ^3.11.0
''');
    final subdir = p.join(fx.root.path, 'lib');
    Directory(subdir).createSync(recursive: true);
    try {
      final result = await runZfaSource([
        'tdd',
        'init',
        '--project',
        other.path,
      ], workingDirectory: subdir);
      expect(combinedOutput(result), isNot(contains('❌')));
      // An explicit --project must win over the walked-up root: the
      // baseline lands in `other`, NOT in fx.root (where the cwd-based
      // walk-up would have put it).
      expect(
        File(p.join(other.path, '.specify/memory/tdd-profile.md')).existsSync(),
        isTrue,
        reason: 'the baseline must land at the explicit --project root',
      );
      expect(
        File(p.join(fx.root.path, 'dart_test.yaml')).existsSync(),
        isFalse,
        reason:
            'the walked-up root must not be touched when --project '
            'is explicit',
      );
    } finally {
      other.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('ProjectRoot.find walks up from a nested subdirectory to the root', () {
    final nested = Directory(p.join(fx.root.path, 'lib', 'src', 'deep'))
      ..createSync(recursive: true);
    expect(ProjectRoot.find(startPath: nested.path), fx.root.path);
  });
}
