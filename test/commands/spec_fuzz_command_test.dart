/// CLI-surface tests for `zfa spec fuzz` (spec 0967-spec-mutation-arena):
/// command registration, flags, usage errors, the drift pre-gate, and
/// the corpus misfire path — driven in-process through the real
/// `CliRunner.runCapturing` (the house pattern).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late CliRunner runner;
  late Directory tmp;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tmp = await Directory.systemTemp.createTemp('spec_fuzz_cmd_');
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  Future<String> drive(List<String> args) =>
      runner.runCapturing(['spec', ...args]);

  const kSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: cmd fixture

**Feature Branch**: `cmd-fixture`

## User Scenarios & Testing *(mandatory)*

**Acceptance Scenarios**:

1. **Given** any user, **When** the feature runs, **Then** it shows the message 'Hi'.
   **Type**: acceptance
''';

  Future<String> seedFeature({
    String spec = kSpec,
    bool withArtifacts = true,
  }) async {
    final feature = 'cmd-fixture';
    final featureDir = p.join(tmp.path, 'specs', feature);
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
    if (withArtifacts) {
      await File(p.join(featureDir, 'tdd', 'artifacts.json')).writeAsString(
        jsonEncode({
          'feature': feature,
          'records': [
            {
              'behavior_id': 'A1',
              'feature': feature,
              'source_criterion': 'AC-1',
              'test_path': 'test/tdd/cmd-fixture/a1_test.dart',
              'subject_path': 'lib/tdd/cmd-fixture/a1_subject.dart',
              'runnable_test_name': 'A1 — cmd',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-09-05T00:00:00Z',
            },
          ],
        }),
      );
    }
    return feature;
  }

  group('registration', () {
    test('the spec group exists with the fuzz subcommand', () async {
      final out = await drive(['--help']);
      expect(out, contains('spec'));
      expect(out, contains('fuzz'));
      expect(out, isNot(contains('Unknown command')));
    });

    test('zfa spec fuzz --help lists the declared flags', () async {
      final out = await drive(['fuzz', '--help']);
      expect(out, contains('--operators'));
      expect(out, contains('--budget'));
      expect(out, contains('--seed'));
      expect(out, contains('--json'));
      expect(out, contains('--no-ledger'));
      expect(out, contains('--corpus'));
      expect(out, contains('--timeout'));
      expect(out, contains('--runner'));
    });
  });

  group('usage errors (exit 64)', () {
    test('unknown operator name is refused with the fix line', () async {
      final out = await drive([
        'fuzz',
        'cmd-fixture',
        '--operators',
        'weaken,nuke',
        '--project',
        tmp.path,
      ]);
      expect(exitCode, 64);
      expect(out, contains('nuke'));
    });

    test('a feature name that is a path segment is refused', () async {
      final out = await drive(['fuzz', '../../etc', '--project', tmp.path]);
      expect(exitCode, 64);
      expect(out, contains('single directory name without path separators'));
    });

    test('a non-integer budget is refused', () async {
      final out = await drive([
        'fuzz',
        'cmd-fixture',
        '--budget',
        'many',
        '--project',
        tmp.path,
      ]);
      expect(exitCode, 64);
      expect(out, contains('--budget'));
    });

    test('a non-integer seed is refused', () async {
      final out = await drive([
        'fuzz',
        'cmd-fixture',
        '--seed',
        'later',
        '--project',
        tmp.path,
      ]);
      expect(exitCode, 64);
      expect(out, contains('--seed'));
    });

    test('budget below one is refused', () async {
      final out = await drive([
        'fuzz',
        'cmd-fixture',
        '--budget',
        '0',
        '--project',
        tmp.path,
      ]);
      expect(exitCode, 64);
      expect(out, contains('--budget'));
    });

    test('a bad --runner value is refused (issue #1044 semantics)', () async {
      final out = await drive([
        'fuzz',
        'cmd-fixture',
        '--runner',
        'mocha',
        '--project',
        tmp.path,
      ]);
      expect(exitCode, 64);
      expect(out, contains("--runner accepts 'dart' or 'flutter'"));
    });

    test('a feature and --corpus together is a usage error', () async {
      await seedFeature();
      final out = await drive([
        'fuzz',
        'cmd-fixture',
        '--corpus',
        'main',
        '--project',
        tmp.path,
      ]);
      expect(exitCode, 64);
      expect(out, contains('either'));
    });
  });

  group('pre-gates', () {
    test('spec drift against the traceability hash is exit 3', () async {
      final feature = await seedFeature();
      final featureDir = p.join(tmp.path, 'specs', feature);
      // A stale traceability hash: the plan recorded a different spec
      // contract than the one on disk.
      await File(p.join(featureDir, 'tdd', 'traceability.md')).writeAsString('''
# Traceability: $feature

<!-- tdd:traceability
spec-hash: sha256:${'0' * 64}
statements: 1
automated: 1
manual: 0
open-gaps: 0
-->
''');
      final out = await drive([
        'fuzz',
        feature,
        '--project',
        tmp.path,
        '--no-ledger',
      ]);
      expect(exitCode, 3);
      expect(out, contains('DRIFT'));
      expect(out, contains('re-plan'));
    });

    test('missing spec.md is not_assessed (exit 64, honest refusal)', () async {
      final feature = 'no-spec-fixture';
      await Directory(
        p.join(tmp.path, 'specs', feature, 'tdd'),
      ).create(recursive: true);
      final out = await drive([
        'fuzz',
        feature,
        '--project',
        tmp.path,
        '--no-ledger',
      ]);
      expect(exitCode, 64);
      expect(out, contains('not_assessed'));
    });
  });

  group('corpus mode', () {
    test('a missing catalog is a misfire with the recovery line', () async {
      final out = await drive([
        'fuzz',
        '--corpus',
        'ghost-target',
        '--project',
        tmp.path,
      ]);
      expect(exitCode, 2);
      expect(out, contains('zfa corpus catalog --target ghost-target'));
    });
  });
}
