@Tags(['e2e'])
// Issue #1417 — speckit scaffolding regenerable into existing repos.
//
// `zfa initialize --speckit` emits the current speckit helper scripts
// (`common.sh`, `setup-plan.sh`, `check-prerequisites.sh`, `setup-tasks.sh`)
// into an existing repo's `.specify/scripts/bash/`, embedded in the CLI so
// they are versioned with it (no drift). Without `--force` the emission never
// clobbers committed scaffolding; the `.gitignore` exclusion that caused the
// original exit-127 misfire is handled by an idempotent force-include block.
//
// Spec: .specify/specs/1417-speckit-scaffolding-regeneration/spec.md
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';
import 'package:zuraffa/src/commands/speckit_scaffolding.dart';

import '../helpers/run_zfa_source.dart';

/// The four Step-1 helper scripts the speckit-* skills require (spec FR-001).
const kSpeckitScripts = [
  'common.sh',
  'setup-plan.sh',
  'check-prerequisites.sh',
  'setup-tasks.sh',
];

/// In-process unit group label — the mutation audit (mutation-test-1417.xml)
/// scopes its per-mutant runs to this group: it exercises the writer logic
/// directly (no CLI subprocess), so a mutant costs seconds instead of an
/// AOT rebuild (see tools/run-tdd-tests.sh for the same repo pattern).
const kWriterUnitGroup = 'SpeckitScaffoldingWriter unit';

void main() {
  setUpAll(() async {
    await initZfaSourceBin();
  });

  Directory useSandbox(Directory base, String name) {
    final dir = Directory(p.join(base.path, name))..createSync(recursive: true);
    return dir;
  }

  group('InitializeCommand --speckit (issue #1417)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('zfa_init1417_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('U-1417-b1: parser exposes --speckit', () {
      final parser = InitializeCommand.buildParser();
      expect(parser.options, contains('speckit'));
      expect(parser.parse(['--speckit'])['speckit'], isTrue);
    });

    test('U-1417-b2: --speckit emits the four Step-1 helper scripts', () async {
      final repoDir = useSandbox(tempDir, 'agent_repo');

      final result = await runZfaSource([
        'initialize',
        '--speckit',
        '--root',
        repoDir.path,
      ], workingDirectory: zfaProjectRoot);

      expect(
        result.exitCode,
        0,
        reason:
            'stdout+stderr: ${result.stdout}'
            '\n${result.stderr}',
      );
      final bashDir = Directory(
        p.join(repoDir.path, '.specify', 'scripts', 'bash'),
      );
      for (final script in kSpeckitScripts) {
        final file = File(p.join(bashDir.path, script));
        expect(file.existsSync(), isTrue, reason: 'missing $script');
        expect(
          file.lengthSync(),
          greaterThan(0),
          reason: '$script must not be empty',
        );
      }
    });

    test(
      'U-1417-b3: emitted setup-plan.sh runs for an existing spec (E2E)',
      () async {
        final repoDir = useSandbox(tempDir, 'agent_repo');
        // A repo shape like the #1417 repro: specs/002-… exists, no scripts.
        final specDir = Directory(
          p.join(repoDir.path, 'specs', '002-engine-core-loop'),
        )..createSync(recursive: true);
        File(p.join(specDir.path, 'spec.md')).writeAsStringSync('# Spec\n');

        final result = await runZfaSource([
          'initialize',
          '--speckit',
          '--root',
          repoDir.path,
        ], workingDirectory: zfaProjectRoot);
        expect(result.exitCode, 0);

        // The skills establish the feature context before Step 1
        // (speckit-specify persists .specify/feature.json) — model that.
        File(
          p.join(repoDir.path, '.specify', 'feature.json'),
        ).writeAsStringSync(
          '{"feature_directory":"specs/002-engine-core-loop"}\n',
        );

        final proc = await Process.run('bash', [
          '.specify/scripts/bash/setup-plan.sh',
          '--json',
        ], workingDirectory: repoDir.path);
        expect(
          proc.exitCode,
          0,
          reason: 'setup-plan.sh stderr: ${proc.stderr}',
        );
        final json = proc.stdout.toString();
        expect(json, contains('"FEATURE_SPEC"'));
        expect(json, contains('specs/002-engine-core-loop/spec.md'));
        expect(json, contains('"BRANCH"'));
        // The pre-fix failure mode was exit 127 "No such file or directory";
        // the script now exists, runs, and resolves the feature contract.
        expect(
          proc.stderr.toString(),
          isNot(contains('No such file or directory')),
        );
      },
    );

    test(
      'U-1417-b4: re-run without --force never clobbers scaffolding',
      () async {
        final repoDir = useSandbox(tempDir, 'committed_repo');
        final bashDir = Directory(
          p.join(repoDir.path, '.specify', 'scripts', 'bash'),
        )..createSync(recursive: true);
        final sentinel = File(p.join(bashDir.path, 'setup-plan.sh'));
        sentinel.writeAsStringSync('#!/usr/bin/env bash\necho committed\n');

        final first = await runZfaSource([
          'initialize',
          '--speckit',
          '--root',
          repoDir.path,
        ], workingDirectory: zfaProjectRoot);
        expect(first.exitCode, 0);
        // The other three scripts were emitted; the committed one is skipped.
        expect(sentinel.readAsStringSync(), contains('echo committed'));

        final second = await runZfaSource([
          'initialize',
          '--speckit',
          '--root',
          repoDir.path,
        ], workingDirectory: zfaProjectRoot);
        expect(second.exitCode, 0);
        expect(
          sentinel.readAsStringSync(),
          contains('echo committed'),
          reason: 'committed scaffolding must survive a no-force re-run',
        );
        expect(
          second.stdout.toString() + second.stderr.toString(),
          contains('setup-plan.sh'),
          reason: 'the skip must be reported',
        );
      },
    );

    test('U-1417-b5: --force overwrites with CLI-current content', () async {
      final repoDir = useSandbox(tempDir, 'stale_repo');
      final bashDir = Directory(
        p.join(repoDir.path, '.specify', 'scripts', 'bash'),
      )..createSync(recursive: true);
      File(p.join(bashDir.path, 'setup-plan.sh')).writeAsStringSync('stale\n');

      final result = await runZfaSource([
        'initialize',
        '--speckit',
        '--force',
        '--root',
        repoDir.path,
      ], workingDirectory: zfaProjectRoot);
      expect(result.exitCode, 0);
      final content = File(
        p.join(bashDir.path, 'setup-plan.sh'),
      ).readAsStringSync();
      expect(content, isNot(contains('stale')));
      expect(content, contains('JSON_MODE'));
    });

    test('U-1417-b6: .gitignore with .specify/* gets the block once', () async {
      final repoDir = useSandbox(tempDir, 'ignored_repo');
      final gitignore = File(p.join(repoDir.path, '.gitignore'));
      gitignore.writeAsStringSync('build/\n.specify/*\n');

      final first = await runZfaSource([
        'initialize',
        '--speckit',
        '--root',
        repoDir.path,
      ], workingDirectory: zfaProjectRoot);
      expect(first.exitCode, 0);

      final content = gitignore.readAsStringSync();
      expect(content, contains('!.specify/scripts'));
      final occurrences = '!'.allMatches(
        content
            .split('\n')
            .where((l) => l.contains('.specify/scripts'))
            .join('\n'),
      );
      expect(
        occurrences.length,
        greaterThanOrEqualTo(2),
        reason: 'dir + contents negations must be present',
      );

      final second = await runZfaSource([
        'initialize',
        '--speckit',
        '--root',
        repoDir.path,
      ], workingDirectory: zfaProjectRoot);
      expect(second.exitCode, 0);
      final after = gitignore.readAsStringSync();
      expect(
        after.indexOf('# zfa initialize --speckit'),
        after.lastIndexOf('# zfa initialize --speckit'),
        reason: 'the force-include block must be appended exactly once',
      );
    });

    test('U-1417-b7: .gitignore without .specify rules is untouched', () async {
      final repoDir = useSandbox(tempDir, 'clean_repo');
      final gitignore = File(p.join(repoDir.path, '.gitignore'));
      gitignore.writeAsStringSync('build/\n.dart_tool/\n');

      final result = await runZfaSource([
        'initialize',
        '--speckit',
        '--root',
        repoDir.path,
      ], workingDirectory: zfaProjectRoot);
      expect(result.exitCode, 0);
      expect(gitignore.readAsStringSync(), 'build/\n.dart_tool/\n');
    });

    test('U-1417-b8: works without pubspec.yaml; creates none', () async {
      final repoDir = useSandbox(tempDir, 'no_pubspec');

      final result = await runZfaSource([
        'initialize',
        '--speckit',
        '--root',
        repoDir.path,
      ], workingDirectory: zfaProjectRoot);

      expect(
        result.exitCode,
        0,
        reason: 'stdout+stderr: ${result.stdout}\n${result.stderr}',
      );
      expect(
        File(p.join(repoDir.path, 'pubspec.yaml')).existsSync(),
        isFalse,
        reason: '--speckit is surgical: no pubspec bootstrap',
      );
      expect(
        File(
          p.join(repoDir.path, '.specify', 'scripts', 'bash', 'common.sh'),
        ).existsSync(),
        isTrue,
      );
    });

    test(
      'U-1417-b9: drift guard — embedded copies match canonical scripts',
      () {
        final constants = SpeckitScaffoldingWriter.embeddedScripts();
        expect(
          constants.keys.toSet(),
          equals(SpeckitScaffoldingWriter.scriptNames.toSet()),
        );
        for (final entry in constants.entries) {
          final canonical = File(
            p.join(zfaProjectRoot, '.specify', 'scripts', 'bash', entry.key),
          );
          if (!canonical.existsSync()) {
            // Published-package consumers have no .specify checkout; the guard
            // is only meaningful inside the framework repo.
            continue;
          }
          expect(
            entry.value,
            canonical.readAsStringSync(),
            reason:
                'embedded ${entry.key} diverged from the canonical copy — '
                're-embed via scripts/embed_speckit_scripts.py '
                '(spec FR-002 / SC-003)',
          );
        }
      },
    );
  });

  group(kWriterUnitGroup, () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('zfa_writer1417_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('U1: emit creates bash dir + all four scripts with content', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      const writer = SpeckitScaffoldingWriter();
      final result = await writer.emit(root.path);

      expect(result.created, equals(kSpeckitScripts));
      expect(result.skipped, isEmpty);
      expect(result.overwritten, isEmpty);
      expect(result.gitignoreUpdated, isFalse);
      for (final script in kSpeckitScripts) {
        final file = File(
          p.join(root.path, '.specify', 'scripts', 'bash', script),
        );
        expect(file.existsSync(), isTrue, reason: 'missing $script');
        expect(
          file.readAsStringSync(),
          equals(SpeckitScaffoldingWriter.embeddedScripts()[script]),
          reason: '$script must match the embedded content byte-for-byte',
        );
      }
    });

    test('U2: emit without force skips differing existing scripts', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      final bashDir = Directory(
        p.join(root.path, '.specify', 'scripts', 'bash'),
      )..createSync(recursive: true);
      File(p.join(bashDir.path, 'setup-plan.sh')).writeAsStringSync('old\n');

      const writer = SpeckitScaffoldingWriter();
      final result = await writer.emit(root.path);

      expect(
        result.created,
        equals(kSpeckitScripts.where((s) => s != 'setup-plan.sh').toList()),
      );
      expect(result.skipped, equals(['setup-plan.sh']));
      expect(result.overwritten, isEmpty);
      expect(
        File(p.join(bashDir.path, 'setup-plan.sh')).readAsStringSync(),
        'old\n',
        reason: 'no-force must not clobber',
      );
    });

    test('U3: emit with force overwrites differing existing scripts', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      final bashDir = Directory(
        p.join(root.path, '.specify', 'scripts', 'bash'),
      )..createSync(recursive: true);
      File(p.join(bashDir.path, 'setup-plan.sh')).writeAsStringSync('old\n');

      const writer = SpeckitScaffoldingWriter();
      final result = await writer.emit(root.path, force: true);

      expect(result.overwritten, equals(['setup-plan.sh']));
      expect(
        result.created,
        equals(kSpeckitScripts.where((s) => s != 'setup-plan.sh').toList()),
        reason: 'the three scripts absent from the sandbox are created',
      );
      expect(
        File(p.join(bashDir.path, 'setup-plan.sh')).readAsStringSync(),
        equals(SpeckitScaffoldingWriter.embeddedScripts()['setup-plan.sh']),
      );
    });

    test(
      'U4: identical existing scripts are skipped even under force',
      () async {
        final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
        final bashDir = Directory(
          p.join(root.path, '.specify', 'scripts', 'bash'),
        )..createSync(recursive: true);
        final scripts = SpeckitScaffoldingWriter.embeddedScripts();
        for (final entry in scripts.entries) {
          File(p.join(bashDir.path, entry.key)).writeAsStringSync(entry.value);
        }

        const writer = SpeckitScaffoldingWriter();
        final result = await writer.emit(root.path, force: true);

        expect(result.skipped, equals(kSpeckitScripts));
        expect(result.overwritten, isEmpty);
        expect(result.created, isEmpty);
      },
    );

    test('U5: dry-run writes nothing', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      const writer = SpeckitScaffoldingWriter();
      final result = await writer.emit(root.path, dryRun: true);

      expect(result.created, equals(kSpeckitScripts));
      expect(
        Directory(p.join(root.path, '.specify')).existsSync(),
        isFalse,
        reason: 'dry-run must not create the .specify tree',
      );
    });

    test(
      'U6: .specify/* gitignore gets the force-include block appended once',
      () async {
        final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
        final gitignore = File(p.join(root.path, '.gitignore'));
        gitignore.writeAsStringSync('build/\n.specify/*\n');

        const writer = SpeckitScaffoldingWriter();
        final first = await writer.emit(root.path);
        expect(first.gitignoreUpdated, isTrue);
        expect(first.gitignorePath, gitignore.path);

        final after1 = gitignore.readAsStringSync();
        expect(after1, contains('!.specify/scripts\n'));
        expect(after1, contains('!.specify/scripts/**\n'));
        // Marker must appear exactly once.
        expect('# zfa initialize --speckit'.allMatches(after1).length, 1);

        final second = await writer.emit(root.path);
        // The block appended by the first run satisfies the exclusion check
        // (last-match-wins), so the re-run has nothing to append.
        expect(second.gitignoreUpdated, isFalse);
        expect(
          gitignore.readAsStringSync(),
          after1,
          reason: 're-emission must not duplicate the block',
        );
      },
    );

    test('U7: gitignore without .specify rules is left untouched', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      final gitignore = File(p.join(root.path, '.gitignore'));
      gitignore.writeAsStringSync('build/\n.dart_tool/\n');

      const writer = SpeckitScaffoldingWriter();
      final result = await writer.emit(root.path);
      expect(result.gitignoreUpdated, isFalse);
      expect(gitignore.readAsStringSync(), 'build/\n.dart_tool/\n');
    });

    test('U8: negated .specify rule satisfies the need (no edit)', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      final gitignore = File(p.join(root.path, '.gitignore'));
      gitignore.writeAsStringSync('.specify/*\n!.specify/scripts\n');

      const writer = SpeckitScaffoldingWriter();
      final result = await writer.emit(root.path);
      expect(result.gitignoreUpdated, isFalse);
      expect(gitignore.readAsStringSync(), '.specify/*\n!.specify/scripts\n');
    });

    test('U9: missing .gitignore never creates one', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      const writer = SpeckitScaffoldingWriter();
      final result = await writer.emit(root.path);
      expect(result.gitignoreUpdated, isFalse);
      expect(File(p.join(root.path, '.gitignore')).existsSync(), isFalse);
    });

    test('U10: marker guard — no duplicate block when the user re-excludes '
        'after an append', () async {
      final root = Directory(p.join(tempDir.path, 'repo'))..createSync();
      final gitignore = File(p.join(root.path, '.gitignore'));
      gitignore.writeAsStringSync('.specify/*\n');

      const writer = SpeckitScaffoldingWriter();
      await writer.emit(root.path);
      expect(
        '# zfa initialize --speckit'
            .allMatches(gitignore.readAsStringSync())
            .length,
        1,
      );

      // The user (or a tool) re-excludes the scripts AFTER our block — the
      // file changed between emissions, so the exclusion check fires again.
      gitignore.writeAsStringSync(
        '${gitignore.readAsStringSync()}.specify/scripts\n',
      );

      await writer.emit(root.path);
      expect(
        '# zfa initialize --speckit'
            .allMatches(gitignore.readAsStringSync())
            .length,
        1,
        reason:
            'the marker guard must prevent a second append when the block '
            'is already present (mutation audit M12)',
      );
    });
  });
}
