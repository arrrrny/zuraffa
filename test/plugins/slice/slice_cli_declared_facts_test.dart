@Tags(['slow'])
/// Tests for the slice CLI surface completing the #961 pipeline (issue
/// #1144): the declared-facts flags on `cut` (--feature/--route/
/// --dependency), the `--json` machine verdict on `verify`, and the
/// Flutter-aware suite-driver selection.
///
/// Behaviors:
///   B1: `cut --feature <id> --route ... --dependency ...` records the
///       declared facts in slice.yaml AND composes the runnable sandbox
///       (lib/main.dart, lib/router.dart, lib/di.dart with the
///       sandbox.bind token, the certified fake artifact, specs/<id>/)
///   B2: `cut` with declared routes but no --feature refuses (exit 1)
///   B3: `verify --json` writes verify-verdict.json with the three named
///       checks and exits non-zero when the suite check fails
///   B4: suiteCommandFor picks `flutter` for Flutter packages, `dart`
///       otherwise
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';
import 'package:zuraffa/src/plugins/slice/verifier/suite_command.dart';

import 'helpers/capture_output.dart';
import 'helpers/slice_test_harness.dart';

void main() {
  late String projectRoot;
  late CommandRunner<void> runner;
  late SliceCommand command;

  setUp(() async {
    projectRoot = await freshSliceProject();
    command = SliceCommand(projectRoot: projectRoot);
    runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
  });

  tearDown(() => disposeSliceProject(projectRoot));

  String sandbox() => '$projectRoot/.zuraffa/slices/login_feature';

  Map<String, dynamic> manifest() {
    final content = File('${sandbox()}/slice.yaml').readAsStringSync();
    final doc = loadYaml(content) as Map;
    return {for (final entry in doc.entries) entry.key.toString(): entry.value};
  }

  /// One declared dependency row of the login feature (072 rail shape).
  const dependencyRow =
      'AuthRepository:service:signIn(String email, String password) -> User:'
      'P1:test/mock/dependencies/auth_repository/fake_auth_repository.dart';

  group('slice cut declared facts (issue #1144)', () {
    test(
      'B1: --feature/--route/--dependency compose the runnable sandbox',
      () async {
        // The feature's receipts travel into the sandbox when the host
        // declares them.
        File(p.join(projectRoot, 'specs', 'login', 'spec.md'))
          ..createSync(recursive: true)
          ..writeAsStringSync('# login\n');

        final output = await captureOutput(
          () => runner.run([
            'slice',
            'cut',
            'login_feature',
            '--entry',
            'product',
            '--feature',
            'login',
            '--route',
            '/login:LoginPage',
            '--dependency',
            dependencyRow,
          ]),
        );

        expect(command.exitCode, equals(0), reason: output);

        final doc = manifest();
        final routes = doc['routes'] as YamlList;
        expect((routes.first as Map)['path'], equals('/login'));
        expect((routes.first as Map)['page'], equals('LoginPage'));
        final dependencies = doc['dependencies'] as YamlList;
        expect(
          (dependencies.first as Map)['dependency'],
          equals('AuthRepository'),
        );

        // The composed runnable sandbox: shell, router, mock DI with the
        // binding token, and the certified fake artifact.
        final di = File('${sandbox()}/lib/di.dart').readAsStringSync();
        expect(di, contains("sandbox.bind('dependencies/auth_repository'"));
        expect(
          File('${sandbox()}/lib/main.dart').existsSync(),
          isTrue,
          reason: 'the composed shell bootstrap must exist',
        );
        expect(
          File('${sandbox()}/lib/router.dart').readAsStringSync(),
          contains('/login'),
        );
        final fake = File(
          '${sandbox()}/test/mock/dependencies/auth_repository/'
          'fake_auth_repository.dart',
        );
        expect(fake.existsSync(), isTrue, reason: 'certified fake installed');
        expect(fake.readAsStringSync(), contains('signIn'));
        expect(
          File('${sandbox()}/specs/login/spec.md').existsSync(),
          isTrue,
          reason: 'the feature receipts travel with the slice',
        );
      },
    );

    test('B2: declared routes without --feature refuse (exit 1)', () async {
      final output = await captureOutput(
        () => runner.run([
          'slice',
          'cut',
          'login_feature',
          '--entry',
          'product',
          '--route',
          '/login:LoginPage',
        ]),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('--feature'));
    });
  });

  group('slice verify --json (issue #1144)', () {
    test('B3: writes the verdict and exits non-zero on a red suite', () async {
      await captureOutput(
        () => runner.run([
          'slice',
          'cut',
          'login_feature',
          '--entry',
          'product',
          '--feature',
          'login',
          '--dependency',
          dependencyRow,
        ]),
      );
      expect(command.exitCode, equals(0));

      await captureOutput(
        () => runner.run(['slice', 'verify', '--json', 'login_feature']),
      );

      final verdictFile = File('${sandbox()}/verify-verdict.json');
      expect(
        verdictFile.existsSync(),
        isTrue,
        reason: 'the merge gate consumes verify-verdict.json',
      );
      final verdict = jsonDecode(verdictFile.readAsStringSync()) as Map;
      // The verdict is flat: one named section per check, each with
      // `pass` + `offenders` (slice.receipt.v1 shape).
      final checks = verdict.keys.toSet();
      expect(
        checks,
        containsAll(['selfContainment', 'mockCertification', 'suiteState']),
      );
      // The fixture sandbox declares no runnable suite, so the suite
      // check must FAIL — absence never passes (errors-are-an-api).
      expect(command.exitCode, isNot(equals(0)));
      final suite = verdict['suiteState'] as Map;
      expect(suite['pass'], isFalse);
    });
  });

  group('suite driver selection (issue #1144)', () {
    test(
      'B4: flutter packages test under flutter; dart packages under dart',
      () async {
        final dir = await Directory.systemTemp.createTemp('suite_driver_');
        addTearDown(() => dir.delete(recursive: true));

        // No pubspec: pure Dart.
        expect(suiteCommandFor(dir.path), equals('dart'));

        File('${dir.path}/pubspec.yaml').writeAsStringSync(
          'name: pure\nenvironment:\n  sdk: ^3.11.0\ndependencies:\n  test: ^1.25.0\n',
        );
        expect(suiteCommandFor(dir.path), equals('dart'));

        File('${dir.path}/pubspec.yaml').writeAsStringSync(
          'name: flutry\ndependencies:\n  flutter:\n    sdk: flutter\n',
        );
        expect(suiteCommandFor(dir.path), equals('flutter'));
      },
    );
  });
}
