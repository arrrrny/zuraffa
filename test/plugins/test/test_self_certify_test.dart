import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/commands/test_command.dart';
import 'package:zuraffa/src/plugins/test/test_certifier.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';

/// Spec 980 / FR-001 + FR-002 — the test plugin self-certifies its own
/// output: after writing a test file it runs a scoped `dart analyze` and
/// emits a machine verdict line
/// `test: entity=<X> tests=<N> compile=pass|fail --> fix: <first error>`
/// plus a `--json` envelope `{entity, tests, compile, errors[], schema:1}`.
/// Non-compiling output fails the command — never silent.
void main() {
  group('TestCertification (verdict formatting)', () {
    test(
      'U1 — --json envelope is exactly {entity, tests, compile, errors[], schema:1}',
      () {
        const cert = TestCertification(
          entity: 'Product',
          tests: 2,
          compile: true,
          errors: [],
        );
        expect(cert.toJson(), {
          'entity': 'Product',
          'tests': 2,
          'compile': 'pass',
          'errors': const <dynamic>[],
          'schema': 1,
        });
      },
    );

    test('U2 — pass verdict line has no fix segment', () {
      const cert = TestCertification(
        entity: 'Product',
        tests: 4,
        compile: true,
        errors: [],
      );
      expect(cert.verdictLine, 'test: entity=Product tests=4 compile=pass');
    });

    test('U2 — fail verdict line names the first error after --> fix:', () {
      const cert = TestCertification(
        entity: 'Product',
        tests: 2,
        compile: false,
        errors: [
          TestCompileError(
            file: 'test/domain/usecases/product/get_product_usecase_test.dart',
            line: 3,
            message: "Undefined name 'ProductMockData'.",
          ),
        ],
      );
      expect(
        cert.verdictLine,
        'test: entity=Product tests=2 compile=fail '
        "--> fix: Undefined name 'ProductMockData'.",
      );
    });
  });

  group('ScopedAnalyzer machine-line parsing (U3)', () {
    test('parses ERROR lines and ignores warnings/infos', () {
      const lines = [
        'ERROR|COMPILE_TIME_ERROR|UNDEFINED_IDENTIFIER|/tmp/w/test/a_test.dart|5|12|16|Undefined name.',
        'WARNING|STATIC_WARNING|UNUSED_LOCAL_VARIABLE|/tmp/w/test/a_test.dart|3|7|1|Unused variable.',
        'INFO|HINT|...|/tmp/w/test/a_test.dart|1|1|2|Something.',
      ];
      final errors = ScopedAnalyzer.parseMachineLines(lines);
      expect(errors, hasLength(1));
      expect(errors.single.message, 'Undefined name.');
      expect(errors.single.line, 5);
      expect(errors.single.file, endsWith('a_test.dart'));
    });

    test('message containing pipe characters survives the parse', () {
      const lines = [
        'ERROR|COMPILE_TIME_ERROR|X|/tmp/w/b_test.dart|1|1|2|one|two|three',
      ];
      final errors = ScopedAnalyzer.parseMachineLines(lines);
      expect(errors.single.message, 'one|two|three');
    });
  });

  group('TestSelfCertifier (U4 — injected analyzer)', () {
    test('counts generated test() blocks across files', () async {
      final analyzer = _RecordingAnalyzer(
        const ScopedAnalysisResult(ran: true, errors: []),
      );
      final certifier = TestSelfCertifier(analyzer: analyzer);
      final tmp = await Directory.systemTemp.createTemp('cert_count_');
      try {
        final cert = await certifier.certify(
          entity: 'Product',
          projectRoot: tmp.path,
          files: [
            GeneratedFile(
              path: 'test/a_test.dart',
              type: 'test',
              action: 'created',
              content:
                  "void main() {\n  test('one', () {});\n  test('two', () {});\n}",
            ),
            GeneratedFile(
              path: 'test/b_test.dart',
              type: 'test',
              action: 'created',
              content: "void main() {\n  test('three', () {});\n}",
            ),
          ],
        );
        expect(cert, isNotNull);
        expect(cert!.tests, 3);
        expect(cert.compile, isTrue);
        expect(cert.verdictLine, 'test: entity=Product tests=3 compile=pass');
        // One scoped analyze per written file.
        expect(analyzer.analyzedFiles, hasLength(2));
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test(
      'compile=fail verdict aggregates the first error (fake analyzer)',
      () async {
        final analyzer = _RecordingAnalyzer(
          const ScopedAnalysisResult(
            ran: true,
            errors: [
              TestCompileError(
                file: 'test/a_test.dart',
                line: 7,
                message: 'Broken.',
              ),
            ],
          ),
        );
        final certifier = TestSelfCertifier(analyzer: analyzer);
        final cert = await certifier.certify(
          entity: 'Broken',
          projectRoot: '/tmp/nowhere',
          files: [
            GeneratedFile(
              path: 'test/a_test.dart',
              type: 'test',
              action: 'created',
              content: "test('x', () {});",
            ),
          ],
        );
        expect(cert!.compile, isFalse);
        expect(cert.errors.single.message, 'Broken.');
        expect(cert.toJson()['compile'], 'fail');
      },
    );

    test(
      'analyzer that cannot run certifies compile=fail, never silent',
      () async {
        final certifier = TestSelfCertifier(
          analyzer: _RecordingAnalyzer(
            const ScopedAnalysisResult(ran: false, errors: []),
          ),
        );
        final cert = await certifier.certify(
          entity: 'X',
          projectRoot: '/tmp/nowhere',
          files: [
            GeneratedFile(
              path: 'test/a_test.dart',
              type: 'test',
              action: 'created',
              content: "test('x', () {});",
            ),
          ],
        );
        expect(cert!.compile, isFalse);
        expect(cert.errors, isNotEmpty);
        expect(cert.verdictLine, contains('compile=fail'));
      },
    );

    test('empty file list certifies nothing (null)', () async {
      final certifier = TestSelfCertifier(
        analyzer: _RecordingAnalyzer(
          const ScopedAnalysisResult(ran: true, errors: []),
        ),
      );
      final cert = await certifier.certify(
        entity: 'X',
        projectRoot: '/tmp/nowhere',
        files: [],
      );
      expect(cert, isNull);
    });
  });

  group('real scoped dart analyze (U3 real)', () {
    late Directory workspace;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('cert_real_');
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: cert_real
environment:
  sdk: ^3.11.0
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) await workspace.delete(recursive: true);
    });

    test(
      'deliberately non-compiling fixture fails with verdict + fix line',
      () async {
        final broken = path.join(workspace.path, 'test', 'broken_test.dart');
        await File(broken).parent.create(recursive: true);
        await File(broken).writeAsString('''
void main() {
  test('deliberately broken', () {
    expect(UndefinedThingie.name, 'x');
  });
}
''');

        final certifier = TestSelfCertifier();
        final cert = await certifier.certify(
          entity: 'Broken',
          projectRoot: workspace.path,
          files: [
            GeneratedFile(
              path: 'test/broken_test.dart',
              type: 'test',
              action: 'created',
              content: await File(broken).readAsString(),
            ),
          ],
        );

        expect(cert, isNotNull);
        expect(
          cert!.compile,
          isFalse,
          reason: 'fixture is deliberately non-compiling',
        );
        expect(cert.errors, isNotEmpty);
        expect(
          cert.verdictLine,
          startsWith('test: entity=Broken tests=1 compile=fail'),
        );
        expect(cert.verdictLine, contains('--> fix:'));
        expect(cert.toJson()['errors'], isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('clean fixture certifies compile=pass', () async {
      final clean = path.join(workspace.path, 'test', 'clean_test.dart');
      await File(clean).parent.create(recursive: true);
      // Self-contained (no package imports): the sandbox resolves no
      // dependencies, so a "clean" fixture must not reference `test(...)`.
      await File(clean).writeAsString('''
void main() {
  final names = <String>['get', 'update'];
  assert(names.isNotEmpty);
  print(names.length);
}
''');

      final certifier = TestSelfCertifier();
      final cert = await certifier.certify(
        entity: 'Clean',
        projectRoot: workspace.path,
        files: [
          GeneratedFile(
            path: 'test/clean_test.dart',
            type: 'test',
            action: 'created',
            content: await File(clean).readAsString(),
          ),
        ],
      );

      expect(cert, isNotNull);
      expect(cert!.compile, isTrue, reason: 'fixture compiles');
      expect(cert.errors, isEmpty);
      expect(cert.verdictLine, 'test: entity=Clean tests=0 compile=pass');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('TestCommand integration (A1/A2/A3 — behavioral)', () {
    late Directory workspace;
    late String outputDir;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('cert_cmd_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: cert_cmd
environment:
  sdk: ^3.11.0
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) await workspace.delete(recursive: true);
    });

    Future<void> writeCustomUseCase() async {
      final file = File(
        path.join(
          outputDir,
          'domain',
          'usecases',
          'account',
          'fetch_user_usecase.dart',
        ),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('''
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
    }

    test(
      'A1/U6 — non-compiling generation fails the command (verdict in errors)',
      () async {
        await writeCustomUseCase();

        final result =
            await TestCommand(
              TestPlugin(
                outputDir: outputDir,
                options: const GeneratorOptions(force: true),
              ),
            ).execute([
              'FetchUser',
              '--output',
              outputDir,
              '--domain',
              'account',
              '--force',
            ], exitOnCompletion: false);

        // The sandbox has no zuraffa dependency, so the generated test's
        // imports cannot resolve: a genuinely non-compiling fixture. The
        // command must not claim success.
        expect(
          result.success,
          isFalse,
          reason: 'non-compiling generated test must fail the command',
        );
        expect(
          result.errors.join('\n'),
          contains('compile=fail'),
          reason: 'the machine verdict line must surface in the errors',
        );
        expect(result.files, isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('A2 — injected pass analyzer keeps the command green', () async {
      await writeCustomUseCase();

      final result =
          await TestCommand(
            TestPlugin(
              outputDir: outputDir,
              options: const GeneratorOptions(force: true),
              certifier: TestSelfCertifier(
                analyzer: _RecordingAnalyzer(
                  const ScopedAnalysisResult(ran: true, errors: []),
                ),
              ),
            ),
          ).execute([
            'FetchUser',
            '--output',
            outputDir,
            '--domain',
            'account',
            '--force',
          ], exitOnCompletion: false);

      expect(result.success, isTrue);
      expect(result.files, hasLength(1));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A3 — --json prints a parseable schema:1 envelope on stdout', () async {
      await writeCustomUseCase();

      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        certifier: TestSelfCertifier(
          analyzer: _RecordingAnalyzer(
            const ScopedAnalysisResult(
              ran: true,
              errors: [
                TestCompileError(
                  file:
                      'test/domain/usecases/account/fetch_user_usecase_test.dart',
                  line: 1,
                  message:
                      "Target of URI doesn't exist: 'package:zuraffa/mock.dart'.",
                ),
              ],
            ),
          ),
        ),
      );

      final printed = <String>[];
      await runZoned(
        () async {
          await TestCommand(plugin).execute([
            'FetchUser',
            '--output',
            outputDir,
            '--domain',
            'account',
            '--force',
            '--json',
          ], exitOnCompletion: false);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line),
        ),
      );

      Map<String, dynamic>? envelope;
      for (final line in printed) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map<String, dynamic> && decoded['schema'] == 1) {
            envelope = decoded;
          }
        } catch (_) {
          // Not a JSON line — ignore.
        }
      }
      expect(
        envelope,
        isNotNull,
        reason:
            'no schema:1 envelope printed; stdout was:\n${printed.join('\n')}',
      );
      expect(envelope!['entity'], 'FetchUser');
      expect(envelope['tests'], 1);
      expect(envelope['compile'], 'fail');
      expect(envelope['errors'], isA<List<dynamic>>());
    });

    test('U5 — dry-run generation skips certification', () async {
      await writeCustomUseCase();

      final plugin = TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        certifier: TestSelfCertifier(
          analyzer: _RecordingAnalyzer(
            const ScopedAnalysisResult(ran: true, errors: []),
          ),
        ),
      );

      final result = await TestCommand(plugin).execute([
        'FetchUser',
        '--output',
        outputDir,
        '--domain',
        'account',
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      expect(
        plugin.lastCertification,
        isNull,
        reason: 'no files written -> no verdict',
      );
    });
  });
}

class _RecordingAnalyzer implements ScopedAnalyzer {
  final ScopedAnalysisResult result;
  final List<String> analyzedFiles = [];

  _RecordingAnalyzer(this.result);

  @override
  Future<ScopedAnalysisResult> analyzeFile(
    String projectRoot,
    String filePath,
  ) async {
    analyzedFiles.add(filePath);
    return result;
  }
}
