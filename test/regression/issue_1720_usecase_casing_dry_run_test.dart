import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/builder/patterns/common_patterns.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';
import 'package:zuraffa/src/plugins/test/test_certifier.dart';
import 'package:zuraffa/src/plugins/test/test_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/generators/custom_usecase_generator.dart';
import 'package:zuraffa/src/utils/string_utils.dart';

/// Issue #1720 — `zfa make --usecases` emits non-compiling presenter/
/// controller (wrong identifier casing) and `--dry-run` always reports
/// placeholder fakes for existing usecases.
///
/// Root causes (see .specify/bugs/1720-vpc-usecase-casing-dry-run/):
/// - `--usecases` tokens are carried into generated identifiers as-is
///   (`login` → `loginUseCase`) instead of the real PascalCase class name.
/// - The test builder unconditionally re-appends the `UseCase` suffix when
///   building fake class/interface names (`LoginUseCase` →
///   `LoginUseCaseUseCase`), so the class-declaration check never matches an
///   existing usecase file → spurious "placeholder fake / interface not
///   declared" warnings.
///
/// These tests drive the public plugin APIs against a temp project whose
/// usecases already exist on disk (the issue's repro state).
void main() {
  group(
    'parseUseCaseInfo normalizes --usecases tokens to PascalCase (#1720)',
    () {
      late Directory tempDir;
      late String outputDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('zfa_1720_parse_');
        outputDir = tempDir.path;
        writeUsecases(outputDir, const [
          'login',
          'logout',
          'sign_in_with_google',
        ]);
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      Future<dynamic> parse(String token) {
        return CommonPatterns.parseUseCaseInfo(
          token,
          GeneratorConfig(name: 'Auth', domain: 'auth', outputDir: outputDir),
          outputDir,
        );
      }

      test('snake_case token login → LoginUseCase', () async {
        final info = await parse('login');
        expect(info.className, 'LoginUseCase');
      });

      test(
        'snake_case token sign_in_with_google → SignInWithGoogleUseCase',
        () async {
          final info = await parse('sign_in_with_google');
          expect(info.className, 'SignInWithGoogleUseCase');
        },
      );

      test('PascalCase token LoginUseCase is not doubled', () async {
        final info = await parse('LoginUseCase');
        expect(info.className, 'LoginUseCase');
      });

      test('camelCase token loginUseCase is normalized, not doubled', () async {
        final info = await parse('loginUseCase');
        expect(info.className, 'LoginUseCase');
      });

      test('fieldName derivation is unchanged (login → login)', () async {
        final info = await parse('login');
        expect(info.fieldName, 'login');
      });

      test('fieldName derivation is unchanged (sign_in_with_google)', () async {
        final info = await parse('sign_in_with_google');
        expect(info.fieldName, 'sign_in_with_google');
      });
    },
  );

  group(
    'presenter emits PascalCase usecase refs matching its imports (#1720)',
    () {
      late Directory tempDir;
      late String outputDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('zfa_1720_pres_');
        // Flutter flavor marker — presenters are skipped for pure-Dart targets
        // (issue #420).
        await File(path.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: issue_1720_presenter_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.1.0
''');
        outputDir = tempDir.path;
        writeUsecases(outputDir, const [
          'login',
          'logout',
          'sign_in_with_google',
        ]);
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      PresenterPlugin buildPlugin() => PresenterPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );

      Future<String> generatePresenter(List<String> usecases) async {
        final files = await buildPlugin().generate(
          GeneratorConfig(
            name: 'Auth',
            domain: 'auth',
            noEntity: true,
            usecases: usecases,
            generatePresenter: true,
            generateDi: true,
            outputDir: outputDir,
          ),
        );
        expect(files, hasLength(1), reason: 'one presenter file');
        return files.single.content!;
      }

      test('lowercase tokens emit PascalCase getIt type refs', () async {
        final content = await generatePresenter(const [
          'login',
          'logout',
          'sign_in_with_google',
        ]);

        // The generated presenter must reference the real classes its own
        // imports declare.
        expect(content, contains('getIt<LoginUseCase>()'));
        expect(content, contains('getIt<LogoutUseCase>()'));
        expect(content, contains('getIt<SignInWithGoogleUseCase>()'));
        expect(content, contains('late final LoginUseCase _login;'));
        expect(
          content,
          contains('late final SignInWithGoogleUseCase _sign_in_with_google;'),
        );

        // No lowercased/mangled class refs may remain.
        expect(content, isNot(contains('getIt<loginUseCase>')));
        expect(content, isNot(contains('getIt<sign_in_with_googleUseCase>')));

        // Import path derivation is unchanged by the fix (regression guard).
        expect(
          content,
          contains(
            "import '../../../domain/usecases/auth/login_usecase.dart';",
          ),
        );
      });

      test('full class name tokens are not suffix-doubled', () async {
        final content = await generatePresenter(const [
          'LoginUseCase',
          'SignInWithGoogleUseCase',
        ]);

        expect(content, contains('getIt<LoginUseCase>()'));
        expect(content, contains('getIt<SignInWithGoogleUseCase>()'));
        expect(content, isNot(contains('UseCaseUseCase')));
      });
    },
  );

  group(
    'test builder detects existing usecases, no placeholder fakes (#1720)',
    () {
      late Directory workspace;
      late String projectRoot;
      late String outputDir;
      late FileSystem fs;

      setUp(() async {
        workspace = await Directory.systemTemp.createTemp('zfa_1720_test_');
        projectRoot = workspace.path;
        outputDir = path.join(projectRoot, 'lib', 'src');
        await Directory(outputDir).create(recursive: true);
        await File(path.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: issue_1720_test_fixture
environment:
  sdk: ^3.11.0
''');
        fs = FileSystem.create(root: projectRoot);
        writeUsecases(outputDir, const [
          'login',
          'logout',
          'sign_in_with_google',
        ]);
      });

      tearDown(() async {
        if (workspace.existsSync()) await workspace.delete(recursive: true);
      });

      TestPlugin plugin() => TestPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: fs,
        certifier: TestSelfCertifier(analyzer: _PassAnalyzer()),
      );

      /// Runs orchestrator test generation capturing all `print` output so the
      /// placeholder-fake warnings ("Generating placeholder Fake... interface
      /// not declared") can be asserted on.
      Future<(String, List<String>)> generateOrchestratorTest(
        List<String> usecases,
      ) async {
        final prints = <String>[];
        final files = await runZoned(
          () => plugin().generate(
            GeneratorConfig(
              name: 'AuthFlow',
              usecases: usecases,
              domain: 'auth',
              outputDir: outputDir,
              generateTest: true,
              force: true,
            ),
          ),
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              prints.add(line);
            },
          ),
        );
        expect(files, hasLength(1), reason: 'one orchestrator test file');
        return (files.single.content!, prints);
      }

      test(
        'lowercase tokens produce real fakes for existing usecases',
        () async {
          final (content, prints) = await generateOrchestratorTest(const [
            'login',
            'logout',
          ]);

          // The fake targets the real declared class, not a mangled name.
          expect(
            content,
            contains('class FakeLoginUseCase implements LoginUseCase'),
          );
          expect(
            content,
            contains('class FakeLogoutUseCase implements LogoutUseCase'),
          );
          expect(content, isNot(contains('FakeloginUseCase')));

          // Existing usecases on disk must be detected: no placeholder warning.
          final placeholderWarnings = prints
              .where((line) => line.contains('placeholder'))
              .toList();
          expect(
            placeholderWarnings,
            isEmpty,
            reason:
                'usecase files exist and '
                'declare the classes; dry-run/test generation must detect them',
          );
        },
      );

      test('full class name tokens are not suffix-doubled', () async {
        final (content, prints) = await generateOrchestratorTest(const [
          'LoginUseCase',
          'LogoutUseCase',
        ]);

        expect(
          content,
          contains('class FakeLoginUseCase implements LoginUseCase'),
        );
        expect(content, isNot(contains('UseCaseUseCase')));
        expect(prints.where((line) => line.contains('placeholder')), isEmpty);
      });
    },
  );

  group('di plugin emits PascalCase getIt refs (#1720)', () {
    late Directory tempDir;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zfa_1720_di_');
      await File(path.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: issue_1720_di_fixture
environment:
  sdk: ^3.11.0
''');
      outputDir = path.join(tempDir.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      writeUsecases(outputDir, const [
        'login',
        'logout',
        'sign_in_with_google',
      ]);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test(
      'lowercase tokens emit PascalCase type refs in DI registrations',
      () async {
        await DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: false,
            verbose: false,
          ),
        ).generate(
          GeneratorConfig(
            name: 'AuthFlow',
            usecases: const ['login', 'logout'],
            domain: 'auth',
            generateDi: true,
            generateUseCase: true,
            outputDir: outputDir,
          ),
        );

        final diFile = File(
          path.join(outputDir, 'di', 'usecases', 'auth_flow_usecase_di.dart'),
        );
        expect(diFile.existsSync(), isTrue);
        final content = diFile.readAsStringSync();

        expect(content, contains('getIt<LoginUseCase>()'));
        expect(content, contains('getIt<LogoutUseCase>()'));
        expect(content, isNot(contains('getIt<loginUseCase>')));
        expect(content, isNot(contains('UseCaseUseCase')));
      },
    );
  });

  group(
    'orchestrator usecase generator emits PascalCase field types (#1720)',
    () {
      late Directory tempDir;
      late String outputDir;
      late FileSystem fs;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('zfa_1720_orch_');
        await File(path.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: issue_1720_orchestrator_fixture
environment:
  sdk: ^3.11.0
''');
        outputDir = tempDir.path;
        fs = FileSystem.create(root: tempDir.path);
        writeUsecases(outputDir, const ['login', 'sign_in_with_google']);
      });

      tearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      test('lowercase tokens emit PascalCase field types', () async {
        final file =
            await CustomUseCaseGenerator(
              outputDir: outputDir,
              options: const GeneratorOptions(force: true),
              fileSystem: fs,
            ).generateOrchestrator(
              GeneratorConfig(
                name: 'AuthFlow',
                domain: 'auth',
                paramsType: 'NoParams',
                usecases: const ['login', 'sign_in_with_google'],
                outputDir: outputDir,
              ),
            );

        final content = file.content!;
        expect(content, contains('final LoginUseCase _login;'));
        expect(
          content,
          contains('final SignInWithGoogleUseCase _sign_in_with_google;'),
        );
        expect(content, isNot(contains('loginUseCase')));
        expect(content, isNot(contains('UseCaseUseCase')));
      });
    },
  );

  group('named usecase class names normalize config.name (#1723 review)', () {
    late Directory tempDir;
    late String outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zfa_1723_named_');
      outputDir = tempDir.path;
      writeUsecases(outputDir, const ['logout']);
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<(String, String)> generateOrchestrator(String name) async {
      final files =
          await CustomUseCaseGenerator(
            outputDir: outputDir,
            options: const GeneratorOptions(force: true),
          ).generateOrchestrator(
            GeneratorConfig(
              name: name,
              useCaseType: 'orchestrator',
              domain: 'auth',
              usecases: const ['logout'],
              paramsType: 'NoParams',
              outputDir: outputDir,
              force: true,
            ),
          );
      return (files.path, files.content!);
    }

    test('raw camelCase config.name emits the PascalCase class', () async {
      final (filePath, content) = await generateOrchestrator('login');
      // The orchestrator file must declare the class parseUseCaseInfo
      // resolves for the consuming --usecases token.
      expect(filePath, endsWith('login_usecase.dart'));
      expect(content, contains('class LoginUseCase'));
      expect(content, isNot(contains('loginUseCase')));
      expect(content, contains('final LogoutUseCase _logout;'));
    });

    test('full class name config.name is not suffix-doubled', () async {
      final (filePath, content) = await generateOrchestrator('loginUseCase');
      expect(filePath, endsWith('login_usecase.dart'));
      expect(content, contains('class LoginUseCase'));
      expect(content, isNot(contains('UseCaseUseCase')));
    });

    test('normalizeUseCaseClassName never doubles the bare token', () {
      expect(StringUtils.normalizeUseCaseClassName('UseCase'), 'UseCase');
    });

    test('GeneratorConfig trims whitespace-padded usecase tokens', () {
      final config = GeneratorConfig(
        name: 'Auth',
        domain: 'auth',
        usecases: const ['login', ' logout', ''],
        outputDir: outputDir,
      );
      expect(config.usecases, ['login', 'logout']);
    });
  });
}

/// Writes minimal existing usecase sources under
/// `<outputDir>/domain/usecases/auth/`, mirroring the issue's repro state
/// (usecases already present in the target project).
void writeUsecases(String outputDir, List<String> tokens) {
  for (final token in tokens) {
    // Fixtures use snake_case tokens (the issue's documented form); the file
    // declares the real PascalCase class, e.g. sign_in_with_google →
    // class SignInWithGoogleUseCase.
    final pascal = token
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
        )
        .join();
    File(
        path.join(
          outputDir,
          'domain',
          'usecases',
          'auth',
          '${token}_usecase.dart',
        ),
      )
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('class ${pascal}UseCase {}');
  }
}

class _PassAnalyzer implements ScopedAnalyzer {
  @override
  Future<ScopedAnalysisResult> analyzeFile(
    String projectRoot,
    String filePath,
  ) async {
    return const ScopedAnalysisResult(ran: true, errors: []);
  }
}
