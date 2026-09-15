@Tags(['slow'])
// Bug #1653 — init's unconditional mutation_test+coverage dev-deps defer a
// multi-minute cold cost into the first analyze-class pass on every fresh
// project (the 8m32s zcalc probe). The remediation makes `mutation_test`
// OPT-IN at init (`--mutation` / `TddBaselineInit(mutation: true)`) and pays
// the cold resolution at INIT time (PubPreResolver) instead of deferring it
// into the first refactor inside a run.
//
// RED first (spec 1653 T003): these tests pin the new contract BEFORE the
// implementation lands.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';
import 'package:zuraffa/src/plugins/tdd/services/baseline_init.dart';
import 'package:zuraffa/src/plugins/tdd/services/pub_pre_resolver.dart';
import 'package:yaml/yaml.dart';

/// A fake process runner for [PubPreResolver]: records invocations, returns
/// the programmed result. No real `pub get` in unit tests.
class _FakePubRunner {
  _FakePubRunner({this.exitCode = 0, this.output = 'Got dependencies!', this.throwOnStart = false});

  final int exitCode;
  final String output;
  final bool throwOnStart;

  final List<String> executables = [];
  final List<List<String>> argvs = [];
  final List<String?> workingDirs = [];

  Future<ProcessResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    executables.add(executable);
    argvs.add(args);
    workingDirs.add(workingDirectory);
    if (throwOnStart) {
      throw const ProcessException('flutter', ['pub', 'get'], 'spawn failed');
    }
    return ProcessResult(0, exitCode, output, '');
  }
}

/// A bare pure-Dart fixture the baseline init can write into.
Directory _dartFixture() {
  final dir = Directory.systemTemp.createTempSync('bug_1653_init_');
  File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: bug1653fixture
environment:
  sdk: ^3.11.0
dependencies: {}
dev_dependencies: {}
''');
  return dir;
}

YamlMap _devDeps(Directory dir) {
  final doc =
      loadYaml(File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync())
          as YamlMap;
  return (doc['dev_dependencies'] as YamlMap?) ?? const YamlMap();
}

void main() {
  group('bug #1653 — patcher opt-in switch (FR-001)', () {
    test('default ensure() does NOT inject mutation_test (dart mode)',
        () async {
      final dir = _dartFixture();
      try {
        final added = await const PubspecDevDependenciesPatcher(
          isFlutter: false,
        ).ensure(dir.path);
        expect(
          added.any((e) => e.startsWith('mutation_test')),
          isFalse,
          reason:
              'issue #1653: mutation_test must not be injected by default — '
              'it is an analyzer-versioned package whose transitive graph '
              'defers a multi-minute cold cost into the first analyze-class '
              'pass on every fresh project',
        );
        expect(_devDeps(dir).containsKey('mutation_test'), isFalse);
        // The rest of the dart baseline is intact.
        expect(_devDeps(dir)['test'], '^1.25.0');
        expect(_devDeps(dir)['coverage'], '^1.15.1');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('default ensure() does NOT inject mutation_test (flutter mode)',
        () async {
      final dir = _dartFixture();
      try {
        final added = await const PubspecDevDependenciesPatcher(
          isFlutter: true,
        ).ensure(dir.path);
        expect(
          added.any((e) => e.startsWith('mutation_test')),
          isFalse,
        );
        expect(_devDeps(dir).containsKey('mutation_test'), isFalse);
        expect(_devDeps(dir)['flutter_test'], 'sdk: flutter');
        expect(_devDeps(dir)['coverage'], '^1.15.1');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('includeMutationTest: true injects mutation_test ^1.8.0 (dart mode)',
        () async {
      final dir = _dartFixture();
      try {
        final added = await const PubspecDevDependenciesPatcher(
          isFlutter: false,
          includeMutationTest: true,
        ).ensure(dir.path);
        expect(added.any((e) => e.startsWith('mutation_test')), isTrue);
        expect(_devDeps(dir)['mutation_test'], '^1.8.0');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('includeMutationTest: true injects mutation_test ^1.8.0 (flutter)',
        () async {
      final dir = _dartFixture();
      try {
        await const PubspecDevDependenciesPatcher(
          isFlutter: true,
          includeMutationTest: true,
        ).ensure(dir.path);
        expect(_devDeps(dir)['mutation_test'], '^1.8.0');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('the static maps keep the #755 verifier pin contract unchanged', () {
      // The opt-in switch filters the INJECTED set; the canonical pins stay
      // asserted so the writer and the MutationVerifier cannot drift.
      expect(
        PubspecDevDependenciesPatcher.flutterDevDependencies['mutation_test'],
        '^1.8.0',
      );
      expect(
        PubspecDevDependenciesPatcher.dartDevDependencies['mutation_test'],
        '^1.8.0',
      );
      expect(
        PubspecDevDependenciesPatcher.flutterDevDependencies['coverage'],
        '^1.15.1',
      );
      expect(
        PubspecDevDependenciesPatcher.dartDevDependencies['coverage'],
        '^1.15.1',
      );
    });

    test('dry-run reports the filtered set too (no mutation_test by default)',
        () async {
      final dir = _dartFixture();
      try {
        final added = await const PubspecDevDependenciesPatcher(
          isFlutter: false,
        ).ensure(dir.path, dryRun: true);
        expect(added.any((e) => e.startsWith('mutation_test')), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('bug #1653 — baseline init threading + pre-resolve (FR-002/004/005)',
      () {
    test('default ensure() writes no mutation_test and SKIPS the resolver '
        'when the baseline was already complete (SC-4 idempotence)', () async {
      final dir = Directory.systemTemp.createTempSync('bug_1653_idem_');
      try {
        File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: idem
environment:
  sdk: ^3.11.0
dependencies: {}
dev_dependencies:
  test: ^1.25.0
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
  coverage: ^1.15.1
''');
        final fake = _FakePubRunner();
        final report = await TddBaselineInit(
          preResolver: PubPreResolver(runProcess: fake.run),
        ).ensure(projectRoot: dir.path);
        expect(report.ok, isTrue);
        expect(
          fake.executables,
          isEmpty,
          reason:
              'an idempotent init pass that added nothing must not re-run the '
              'resolver (issue #1653 SC-4: no repeated cold cost per init)',
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('default ensure() adds dev deps WITHOUT mutation_test (unit lane '
        'threading, FR-002)', () async {
      final dir = _dartFixture();
      try {
        final fake = _FakePubRunner();
        final report = await TddBaselineInit(
          preResolver: PubPreResolver(runProcess: fake.run),
        ).ensure(projectRoot: dir.path);
        expect(report.ok, isTrue);
        expect(_devDeps(dir).containsKey('mutation_test'), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('mutation: true threads the opt-in and still resolves', () async {
      final dir = _dartFixture();
      try {
        final fake = _FakePubRunner();
        final report = await TddBaselineInit(
          preResolver: PubPreResolver(runProcess: fake.run),
        ).ensure(projectRoot: dir.path, mutation: true);
        expect(report.ok, isTrue);
        expect(_devDeps(dir)['mutation_test'], '^1.8.0');
        expect(fake.executables, ['dart']);
        expect(fake.argvs.single, contains('get'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('pre-resolve FIRES when init newly added dev deps (SC-2: the cold '
        'cost is paid at init time)', () async {
      final dir = _dartFixture();
      try {
        final fake = _FakePubRunner();
        final lines = <String>[];
        await TddBaselineInit(
          preResolver: PubPreResolver(runProcess: fake.run),
        ).ensure(
          projectRoot: dir.path,
          onLine: lines.add,
        );
        expect(fake.executables, ['dart']);
        expect(fake.argvs.single, ['pub', 'get', '--no-example']);
        expect(fake.workingDirs.single, dir.path);
        final resolutionLine = lines
            .firstWhere((l) => l.contains('pub resolution'), orElse: () => '');
        expect(
          resolutionLine,
          isNotEmpty,
          reason:
              'init must PRINT the resolution it paid (issue #1653 Ask 2: '
              '"and print it")',
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('a resolver that exits non-zero MISFIRES init (FR-005 fail-closed)',
        () async {
      final dir = _dartFixture();
      try {
        final fake = _FakePubRunner(
          exitCode: 1,
          output: 'version solving failed',
        );
        final errors = <String>[];
        await expectLater(
          TddBaselineInit(
            preResolver: PubPreResolver(runProcess: fake.run),
          ).ensure(projectRoot: dir.path, onError: errors.add),
          throwsA(isA<BaselineInitMisfire>()),
        );
        expect(
          errors.any((l) => l.contains('pub resolution')),
          isTrue,
          reason: 'the ✗ line must name the failed resolution',
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('a missing resolver binary WARNS but does not misfire (FR-005: '
        'nothing proven broken)', () async {
      final dir = _dartFixture();
      try {
        final fake = _FakePubRunner(throwOnStart: true);
        final lines = <String>[];
        final report = await TddBaselineInit(
          preResolver: PubPreResolver(runProcess: fake.run),
        ).ensure(projectRoot: dir.path, onLine: lines.add);
        expect(report.ok, isTrue);
        expect(
          lines.any((l) => l.contains('pub resolution') && l.contains('⚠')),
          isTrue,
          reason:
              'the skip must be LOUD, never silent (the first analyze-class '
              'pass will pay the cold cost)',
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });

  group('bug #1653 — zfa tdd init --mutation (FR-003)', () {
    test('zfa tdd init --help registers the --mutation opt-in', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['tdd', 'init', '--help']);
      expect(
        out,
        contains('--mutation'),
        reason: 'zfa tdd init --mutation must be a registered opt-in flag',
      );
    });

    test('zfa tdd init (default) leaves mutation_test out of the pubspec',
        () async {
      final dir = _dartFixture();
      try {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(['tdd', 'init', '--project', dir.path]);
        expect(_devDeps(dir).containsKey('mutation_test'), isFalse);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('zfa tdd init --mutation adds mutation_test ^1.8.0', () async {
      final dir = _dartFixture();
      try {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'init',
          '--mutation',
          '--project',
          dir.path,
        ]);
        expect(_devDeps(dir)['mutation_test'], '^1.8.0');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
