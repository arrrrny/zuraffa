import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certification_sandbox.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_contract_test_writer.dart';

/// Spec 1600 (issue #1600, #1513 sibling): the mock certification contract
/// test honors the host test framework.
///
/// - B1 — `flutterTest: true` renders the flutter_test import and never
///   plain `package:test` (the #1600 defect: the hardcoded plain import
///   cannot compile on a Flutter host, permanently reding the suite).
/// - B2 — the DEFAULT render stays byte-identical to the pre-fix golden
///   (pure-Dart stability guard, green pre-fix by design).
/// - B3 — the sandbox Flutter manifest declares the Flutter SDK + its test
///   framework; the unset shape is today's exact bytes.
/// - B4 — the sandbox toolchain selection: `flutter` when the flag is set,
///   `dart` (unchanged) when unset; the run reports which toolchain ran.
void main() {
  late Directory tempDir;
  late String outputDir;

  Future<String> golden() async => File(
    p.join(
      Directory.current.path,
      'test',
      'fixtures',
      'baseline_outputs',
      'bug_1600_mock_contract_default_render.txt',
    ),
  ).readAsString();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1600_writer_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'login'),
    );
    entityDir.createSync(recursive: true);
    File(p.join(entityDir.path, 'login.dart')).writeAsStringSync('''
class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});
}
''');
    final dsDir = Directory(p.join(outputDir, 'data', 'datasources', 'login'));
    dsDir.createSync(recursive: true);
    File(p.join(dsDir.path, 'login_datasource.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';
import '../../../domain/entities/login/login.dart';

abstract class LoginDataSource with Loggable, FailureHandler {
  Future<Login> get(QueryParams<Login> params);
  Future<Login> update(UpdateParams<String, LoginPatch> params);
  Future<Login> toggle(ToggleParams<String, Field<Login, dynamic>> params);
}
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('spec 1600 — mock contract test writer honors the host', () {
    test('B2: the default render matches the pre-fix golden byte for byte '
        '(pure-Dart stability guard)', () async {
      final writer = const MockContractTestWriter();
      final contract = (await writer.extractContract('Login', outputDir))!;
      final source = writer.render(
        entityName: 'Login',
        methods: contract,
        projectRoot: tempDir.path,
        outputDir: outputDir,
      );
      expect(source, await golden());
    });

    test('B1: flutterTest renders the flutter_test import and never '
        'package:test', () async {
      final writer = const MockContractTestWriter(flutterTest: true);
      final contract = (await writer.extractContract('Login', outputDir))!;
      final source = writer.render(
        entityName: 'Login',
        methods: contract,
        projectRoot: tempDir.path,
        outputDir: outputDir,
      );
      expect(
        source,
        contains("import 'package:flutter_test/flutter_test.dart';"),
        reason:
            'the Flutter host cannot resolve plain package:test '
            '(the #1600 load error)',
      );
      expect(source, isNot(contains("import 'package:test/test.dart';")));
      // Everything else about the certification pins stays: the interface
      // tear-off surface and the behavioral calls are host-independent.
      expect(source, contains('final LoginDataSource dataSource ='));
      expect(source, contains("group('Login mock contract (spec 1001)'"));
    });

    test('B3: the sandbox Flutter manifest declares the Flutter SDK and its '
        'test framework; the unset manifest is the pure-Dart shape', () {
      final flutterPubspec = MockCertificationSandbox.pubspecFor(
        frameworkRoot: '/framework/root',
        flutterTest: true,
      );
      expect(flutterPubspec, contains('flutter:\n    sdk: flutter'));
      expect(flutterPubspec, contains('flutter_test:\n    sdk: flutter'));
      expect(
        flutterPubspec,
        contains('path: "/framework/root"'),
        reason: 'the zuraffa path dependency is kept on both shapes',
      );
      // flutter_test pins matcher/test_api with which no published `test`
      // version resolves alongside the framework's graphql graph (the
      // #1189 conflict) — the Flutter branch declares flutter_test only.
      expect(flutterPubspec, isNot(contains('test: ^')));

      final dartPubspec = MockCertificationSandbox.pubspecFor(
        frameworkRoot: '/framework/root',
        flutterTest: false,
      );
      expect(dartPubspec, contains('test: ^1.25.0'));
      expect(
        dartPubspec,
        isNot(contains('flutter')),
        reason: 'no Flutter machinery appears on the pure-Dart path',
      );
    });

    test('B4: toolchain selection — flutter when the flag is set, dart '
        'when unset (the default constructor unchanged)', () {
      expect(MockCertificationSandbox.toolchainFor(true), 'flutter');
      expect(MockCertificationSandbox.toolchainFor(false), 'dart');
      expect(MockCertificationSandbox(flutterTest: true).toolchain, 'flutter');
      expect(MockCertificationSandbox().toolchain, 'dart');
    });
  });
}
