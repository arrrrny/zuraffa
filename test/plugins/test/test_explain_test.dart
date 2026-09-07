// Spec 1129 — test plugin: `--explain` flag (A- → A+ upgrade).
//
// The test plugin is at A- after spec 980: it has `--json` (via
// `ExecutionResult.data['certification']`), the AST-based self-certifier,
// provenance headers, receipts, and a `plan()` dry-run. The ONLY gap is
// the missing `--explain` flag. This file pins the A+ contract:
//
//   1. `zfa test create <Entity> --explain` emits the human-readable
//      explain block: which test files were generated, which test kinds
//      (unit/integration/widget) were produced, the self-certification
//      result per file, and the trust tier of the generated artifacts.
//   2. The explain block appears on stdout ALONGSIDE the regular output
//      (the machine verdict line + the created/overwritten file list),
//      never instead of it.
//   3. `--explain --json` produces both JSON (the spec 980 certification
//      envelope, keys unchanged) and prose (the block), envelope first.
//
// Constraints pinned here: `--json` semantics unchanged, the
// self-certification gate behavior unchanged (non-compiling output still
// fails the command), and trust tiers are read-only derivations from the
// certification evidence.
//
// Style: route_explain_test.dart (CommandRunner + capturePrints, real
// generation into a temp project) with the fake ScopedAnalyzer pattern
// from test_plugin_dispatch_test.dart (no `dart analyze` subprocess).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/test_command.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/test/capabilities/create_test_capability.dart';
import 'package:zuraffa/src/plugins/test/test_certifier.dart';
import 'package:zuraffa/src/plugins/test/test_explain.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';
import 'package:zuraffa/src/utils/string_utils.dart';

Future<String> capturePrints(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

/// Fake scoped analyzer: pass every file, or fail every file with one
/// ERROR attributed to the exact path the certifier passes in (the
/// [ScopedAnalyzer] contract — the production analyzer echoes the path).
class _FakeAnalyzer implements ScopedAnalyzer {
  final bool pass;

  const _FakeAnalyzer({required this.pass});

  @override
  Future<ScopedAnalysisResult> analyzeFile(
    String projectRoot,
    String filePath,
  ) async {
    if (pass) return const ScopedAnalysisResult(ran: true, errors: []);
    return ScopedAnalysisResult(
      ran: true,
      errors: [
        TestCompileError(
          file: filePath,
          line: 3,
          message:
              "Target of URI doesn't exist: "
              "'package:sandbox/src/domain/repositories/user_repository.dart'",
        ),
      ],
    );
  }
}

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('spec1129_explain_');
    projectRoot = tempDir.path;
    outputDir = p.join(projectRoot, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: explain_app
environment:
  sdk: ^3.11.0
''');
    final usecase = File(
      p.join(
        outputDir,
        'domain',
        'usecases',
        'general',
        'fetch_user_usecase.dart',
      ),
    );
    await usecase.parent.create(recursive: true);
    await usecase.writeAsString('''
import 'package:zuraffa/zuraffa.dart';

class FetchUserUseCase extends UseCase<User, NoParams> {
  final UserRepository _repository;

  FetchUserUseCase(this._repository);

  @override
  Future<User> execute(NoParams params, CancelToken? cancelToken) async {
    throw UnimplementedError();
  }
}
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    exitCode = 0;
  });

  TestPlugin plugin({required bool pass}) => TestPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(),
    fileSystem: FileSystem.create(root: projectRoot),
    certifier: TestSelfCertifier(analyzer: _FakeAnalyzer(pass: pass)),
  );

  CommandRunner<void> runner({required bool pass}) =>
      CommandRunner<void>('zfa', 'test')
        ..addCommand(TestCommand(plugin(pass: pass), projectRoot: projectRoot));

  group('spec 1129: test create --explain (US1: the explain block)', () {
    test('A1 — emits the separator plus the five mandated sections', () async {
      final out = await capturePrints(
        () => runner(
          pass: true,
        ).run(['test', 'create', 'FetchUser', '--explain']),
      );

      expect(exitCode, 0, reason: 'the certified generation succeeds');
      expect(
        out,
        contains('--- explain: test create ---'),
        reason: 'the block separator (the --explain + --json anchor)',
      );
      expect(out, contains('generated files:'));
      expect(out, contains('test kinds:'));
      expect(out, contains('self-certification:'));
      expect(out, contains('trust tier:'));
      expect(out, contains('summary:'));
      // The generated file is named with its kind and tier.
      expect(out, contains('fetch_user_usecase_test.dart'));
      expect(out, contains('kind=unit'));
      expect(out, contains('tier=certified'));
    });

    test(
      'A2 — the block is additive: verdict line + file list still present',
      () async {
        final out = await capturePrints(
          () => runner(
            pass: true,
          ).run(['test', 'create', 'FetchUser', '--explain']),
        );

        // The regular output the run produces WITHOUT --explain.
        expect(
          out,
          contains('test: entity=FetchUser'),
          reason: 'the machine verdict line still prints',
        );
        expect(out, contains('compile=pass'));
        expect(
          out,
          contains('✅ Success! Created/Modified:'),
          reason: 'the regular file list still prints',
        );
        // Order: regular output first, explain block after it.
        final verdictAt = out.indexOf('test: entity=FetchUser');
        final successAt = out.indexOf('✅ Success! Created/Modified:');
        final explainAt = out.indexOf('--- explain: test create ---');
        expect(verdictAt, greaterThanOrEqualTo(0));
        expect(successAt, greaterThan(verdictAt));
        expect(explainAt, greaterThan(successAt));
      },
    );

    test('A3 — without --explain no separator appears (opt-in flag)', () async {
      final out = await capturePrints(
        () => runner(pass: true).run(['test', 'create', 'FetchUser']),
      );

      expect(exitCode, 0);
      expect(out, contains('test: entity=FetchUser'));
      expect(
        out,
        isNot(contains('--- explain:')),
        reason: 'the flag is opt-in; output is the pre-1129 shape',
      );
    });
  });

  group('spec 1129: test create --explain --json (US2: JSON and prose)', () {
    test(
      'A4 — envelope FIRST, then the prose block; envelope keys unchanged',
      () async {
        final out = await capturePrints(
          () => runner(
            pass: true,
          ).run(['test', 'create', 'FetchUser', '--explain', '--json']),
        );

        expect(exitCode, 0);
        // The envelope is a parseable JSON line with the spec 980 keys.
        final jsonLines = out
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.startsWith('{') && l.endsWith('}'))
            .toList();
        expect(jsonLines, isNotEmpty, reason: 'one parseable JSON envelope');
        final envelope = jsonDecode(jsonLines.first) as Map<String, dynamic>;
        expect(envelope['entity'], 'FetchUser');
        expect(envelope['tests'], 1);
        expect(envelope['compile'], 'pass');
        expect(envelope['errors'], isEmpty);
        expect(envelope['schema'], 1);
        // Then the prose block — after the envelope.
        final envelopeAt = out.indexOf(jsonLines.first);
        final explainAt = out.indexOf('--- explain: test create ---');
        expect(explainAt, greaterThan(envelopeAt));
        expect(out, contains('summary:'));
      },
    );

    test('A5 — --json alone stays envelope-only (no explain prose)', () async {
      final out = await capturePrints(
        () => runner(pass: true).run(['test', 'create', 'FetchUser', '--json']),
      );

      expect(exitCode, 0);
      final jsonLines = out
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.startsWith('{') && l.endsWith('}'))
          .toList();
      expect(jsonLines, isNotEmpty);
      final envelope = jsonDecode(jsonLines.first) as Map<String, dynamic>;
      expect(envelope['compile'], 'pass');
      expect(
        out,
        isNot(contains('--- explain:')),
        reason: '--json semantics unchanged: no prose without --explain',
      );
    });
  });

  group('spec 1129: trust tiers (US3: honest tiers)', () {
    test(
      'A6 — passing analyzer: every written file tier=certified, block certified',
      () async {
        final out = await capturePrints(
          () => runner(
            pass: true,
          ).run(['test', 'create', 'FetchUser', '--explain']),
        );

        expect(exitCode, 0);
        expect(out, contains('tier=certified'));
        expect(out, contains('trust tier: certified'));
      },
    );

    test(
      'A7 — failing analyzer: offending file tier=failed with the error, block failed, exit 1',
      () async {
        final out = await capturePrints(
          () => runner(
            pass: false,
          ).run(['test', 'create', 'FetchUser', '--explain']),
        );

        // The self-certification gate is unchanged: non-compiling output fails.
        expect(exitCode, 1);
        expect(out, contains('compile=fail'));
        expect(out, contains('tier=failed'));
        expect(
          out,
          contains(
            "Target of URI doesn't exist: "
            "'package:sandbox/src/domain/repositories/user_repository.dart'",
          ),
          reason: 'the first error is quoted in the certification section',
        );
        expect(out, contains('trust tier: failed'));
        // Honesty on every exit path: the block still prints.
        expect(out, contains('--- explain: test create ---'));
      },
    );

    test(
      'A8 — all-skipped run: pre-existing files listed, honest unverified block tier',
      () async {
        // First run writes the file (created).
        await capturePrints(
          () => runner(pass: true).run(['test', 'create', 'FetchUser']),
        );
        // Second run without --force: the file is skipped (pre-existing);
        // this run wrote nothing and certified nothing.
        final out = await capturePrints(
          () => runner(
            pass: true,
          ).run(['test', 'create', 'FetchUser', '--explain']),
        );

        expect(exitCode, 0);
        expect(out, contains('⏭ Skipped'));
        expect(out, contains('tier=pre-existing'));
        expect(
          out,
          contains('trust tier: unverified'),
          reason:
              'honesty: this run wrote nothing and certified nothing '
              '(pre-existing files never RAISE the tier either)',
        );
      },
    );

    test(
      'U6 — pure builder: pre-existing never lowers the floor of a mixed run',
      () {
        // A mixed run: one written + certified file, one skipped file.
        final written = GeneratedFile(
          path: '/tmp/x/test/a_test.dart',
          type: 'test',
          action: 'created',
          content:
              "import 'package:test/test.dart';\nvoid main() { test('a', () {}); }\n",
        );
        final skipped = GeneratedFile(
          path: '/tmp/x/test/b_test.dart',
          type: 'test',
          action: 'skipped',
        );
        final out = buildTestExplain(
          entity: 'Mixed',
          files: [written, skipped],
          certification: const TestCertification(
            entity: 'Mixed',
            tests: 1,
            compile: true,
            errors: [],
          ),
        );

        expect(
          out,
          contains(
            '- /tmp/x/test/a_test.dart (created) kind=unit tier=certified',
          ),
        );
        expect(
          out,
          contains(
            '- /tmp/x/test/b_test.dart (skipped) kind=unit tier=pre-existing',
          ),
        );
        expect(
          out,
          contains('trust tier: certified'),
          reason: 'pre-existing files never lower the written files floor',
        );
      },
    );

    test('U5 — pure builder: tier attribution and the floor rule', () {
      final written = GeneratedFile(
        path: '/tmp/x/test/a_test.dart',
        type: 'test',
        action: 'overwritten',
        content: "import 'package:test/test.dart';",
      );
      // Attributed error ⇒ failed file, failed block.
      final failed = buildTestExplain(
        entity: 'X',
        files: [written],
        certification: const TestCertification(
          entity: 'X',
          tests: 1,
          compile: false,
          errors: [
            TestCompileError(
              file: '/tmp/x/test/a_test.dart',
              line: 3,
              message: 'uri does not exist',
            ),
          ],
        ),
      );
      expect(failed, contains('tier=failed'));
      expect(failed, contains('FAIL — uri does not exist'));
      expect(failed, contains('trust tier: failed'));

      // No certification evidence ⇒ unverified file, unverified block.
      final unverified = buildTestExplain(
        entity: 'X',
        files: [written],
        certification: null,
      );
      expect(unverified, contains('tier=unverified'));
      expect(unverified, contains('trust tier: unverified'));
    });
  });

  group('spec 1129: capability contract (data, not just CLI)', () {
    test(
      'U9 — explain:true attaches data[explain]; certification shape unchanged',
      () async {
        final capability = CreateTestCapability(plugin(pass: true));

        final result = await capability.execute({
          'name': 'FetchUser',
          'domain': 'general',
          'explain': true,
        });

        expect(result.success, isTrue, reason: result.message);
        final explain = result.data?['explain'] as String?;
        expect(explain, isNotNull);
        expect(explain, contains('--- explain: test create ---'));
        expect(explain, contains('generated files:'));
        expect(explain, contains('test kinds:'));
        expect(explain, contains('self-certification:'));
        expect(explain, contains('trust tier:'));
        expect(explain, contains('summary:'));

        // The spec 980 --json contract is untouched.
        final certification = result.data?['certification'];
        expect(certification, isA<Map<String, dynamic>>());
        expect(
          (certification as Map<String, dynamic>).keys,
          containsAll(['entity', 'tests', 'compile', 'errors', 'schema']),
        );
        expect(certification['schema'], 1);
      },
    );

    test('U9b — without explain:true data[explain] stays absent', () async {
      final capability = CreateTestCapability(plugin(pass: true));

      final result = await capability.execute({
        'name': 'FetchUser',
        'domain': 'general',
      });

      expect(result.success, isTrue);
      expect(result.data?['explain'], isNull);
      expect(result.data?['certification'], isNotNull);
    });
  });

  group('spec 1129: grammar parity (manifest treaty)', () {
    test(
      'U12 — every inputSchema property resolves to a registered, help-advertised flag',
      () {
        final command = TestCommand(
          plugin(pass: true),
          projectRoot: projectRoot,
        );
        // Command.usage needs the root parented by a runner (package:args
        // walks parent.invocation to render the usage surface).
        final tree = CommandRunner<void>('zfa', 'zfa')..addCommand(command);
        final serving = tree.commands['test']!.subcommands['create'];
        expect(
          serving,
          isNotNull,
          reason: 'create resolves in the command tree',
        );

        final props =
            CreateTestCapability(plugin(pass: true)).inputSchema['properties']
                as Map<String, dynamic>;
        expect(
          props.containsKey('explain'),
          isTrue,
          reason: 'the schema advertises the flag',
        );

        for (final prop in props.keys) {
          final flagName = prop.contains('-')
              ? prop
              : StringUtils.camelToSnake(prop).replaceAll('_', '-');
          expect(
            serving!.argParser.options.containsKey(flagName),
            isTrue,
            reason: 'schema prop "$prop" must be accepted by the parser',
          );
          expect(
            serving.usage,
            contains('--$flagName'),
            reason: 'help text must advertise --$flagName (no drift)',
          );
        }
      },
    );

    test(
      'U7 — the positional entity and the flags map onto the capability args',
      () async {
        final out = await capturePrints(
          () => runner(pass: true).run([
            'test',
            'create',
            'FetchUser',
            '--domain',
            'general',
            '--explain',
          ]),
        );

        expect(exitCode, 0);
        expect(out, contains('test: entity=FetchUser'));
        expect(out, contains('--- explain: test create ---'));
      },
    );
  });
}
