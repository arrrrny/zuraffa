import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/certify_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certification_sandbox.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_contract_test_writer.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certifier.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/core/generator_options.dart';

/// Spec 1600 (issue #1600): the certifier honors the host test framework
/// end to end.
///
/// - B5 — the create re-pin path (`certify(rePin: true)`) renders a
///   Flutter-shaped contract test on a Flutter host (assertion red pre-fix:
///   the #1600 defect — the certified source was Dart-shaped).
/// - B6 — `MockCertifier.forProject` detection matrix: flutter pubspec →
///   Flutter-shaped certifier (writer + sandbox); pure-Dart / unreadable /
///   absent pubspec → today's Dart shape; the default constructor
///   unchanged.
/// - B8 — the certify fresh-render path (`rePin: false`, no committed
///   test) emits the same Flutter-shaped surface (assertion red pre-fix).
///
/// The proof machinery is stubbed green (_StubGreenSandbox): the render
/// surface is what this file pins, without executing any toolchain — the
/// live Flutter-toolchain proof is the integration tier (B9/B10).
void main() {
  late Directory tempDir;
  late String flutterFixture;
  late String dartFixture;

  /// Writes the mock artifacts certify needs (interface + entity for the
  /// contract, existence-only mock datasource + mock data).
  Future<String> scaffoldFixture({
    required String pubspecContent,
    bool withMockArtifacts = true,
  }) async {
    final root = await Directory.systemTemp.createTemp('zfa_1600_cert_');
    final out = p.join(root.path, 'lib', 'src');
    final entityDir = Directory(p.join(out, 'domain', 'entities', 'login'));
    entityDir.createSync(recursive: true);
    File(p.join(entityDir.path, 'login.dart')).writeAsStringSync('''
class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});
}
''');
    final dsDir = Directory(p.join(out, 'data', 'datasources', 'login'));
    dsDir.createSync(recursive: true);
    File(p.join(dsDir.path, 'login_datasource.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';
import '../../../domain/entities/login/login.dart';

abstract class LoginDataSource with Loggable, FailureHandler {
  Future<Login> get(QueryParams<Login> params);
  Future<Login> update(UpdateParams<String, LoginPatch> params);
}
''');
    if (withMockArtifacts) {
      File(
        p.join(dsDir.path, 'login_mock_datasource.dart'),
      ).writeAsStringSync('// mock subject (existence for certify)\n');
      final mockDir = Directory(p.join(out, 'data', 'mock'));
      mockDir.createSync(recursive: true);
      File(
        p.join(mockDir.path, 'login_mock_data.dart'),
      ).writeAsStringSync('// mock data (existence for certify)\n');
    }
    if (pubspecContent.isNotEmpty) {
      File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(pubspecContent);
    }
    return root.path;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1600_cap_');
    flutterFixture = await scaffoldFixture(
      pubspecContent: '''
name: flutter_host
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''',
    );
    dartFixture = await scaffoldFixture(
      pubspecContent: '''
name: dart_host
environment:
  sdk: ^3.11.0
dependencies:
  http: ^1.2.0
''',
    );
  });

  tearDown(() async {
    for (final dir in [
      tempDir,
      Directory(flutterFixture),
      Directory(dartFixture),
    ]) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  group('spec 1600 — the certifier honors the host', () {
    test('B5: the create re-pin path renders a Flutter-shaped contract '
        'test on a Flutter host', () async {
      final certifier = MockCertifier.forProject(
        flutterFixture,
        sandbox: _StubGreenSandbox(methods: const ['get', 'update']),
      );
      final outcome = await certifier.certify(
        entityName: 'Login',
        projectRoot: flutterFixture,
        outputDir: p.join(flutterFixture, 'lib', 'src'),
        rePin: true,
      );

      expect(
        outcome.certified,
        isTrue,
        reason:
            'the stubbed proof is green; the render must not be the '
            'reason certification dies',
      );
      final source = outcome.contractTestSource!;
      expect(
        source,
        contains("import 'package:flutter_test/flutter_test.dart';"),
        reason:
            'the committed test must compile on the Flutter host '
            '(the #1600 load error)',
      );
      expect(source, isNot(contains("import 'package:test/test.dart';")));
    });

    test('B6: forProject detects the host from the pubspec — flutter, '
        'pure-Dart, unreadable, and absent shapes', () {
      final flutter = MockCertifier.forProject(flutterFixture);
      expect(
        flutter.contractWriter.testImport,
        'package:flutter_test/flutter_test.dart',
      );
      expect(flutter.sandbox.flutterTest, isTrue);

      final dart = MockCertifier.forProject(dartFixture);
      expect(dart.contractWriter.testImport, 'package:test/test.dart');
      expect(dart.sandbox.flutterTest, isFalse);

      // Unreadable pubspec: NOT a Flutter host, never a crash.
      final unreadableFixture = Directory.systemTemp.createTempSync(
        'zfa_1600_bad_',
      );
      File(
        p.join(unreadableFixture.path, 'pubspec.yaml'),
      ).writeAsStringSync('::: not yaml [ ::\n');
      final unreadable = MockCertifier.forProject(unreadableFixture.path);
      expect(unreadable.contractWriter.testImport, 'package:test/test.dart');
      expect(unreadable.sandbox.flutterTest, isFalse);
      unreadableFixture.deleteSync(recursive: true);

      // Absent pubspec: the pure-Dart default.
      final absent = MockCertifier.forProject(tempDir.path);
      expect(absent.contractWriter.testImport, 'package:test/test.dart');
      expect(absent.sandbox.flutterTest, isFalse);

      // Guard: the bare constructor stays Dart-shaped (byte-stable
      // default — FR-006).
      final bare = MockCertifier();
      expect(bare.contractWriter.testImport, 'package:test/test.dart');
      expect(bare.sandbox.flutterTest, isFalse);
    });

    test('B8: the certify fresh-render path emits the same Flutter-shaped '
        'surface (no committed contract test)', () async {
      // No committed contract test in the fixture → certify renders fresh.
      final certifier = MockCertifier.forProject(
        flutterFixture,
        sandbox: _StubGreenSandbox(methods: const ['get', 'update']),
      );
      final outcome = await certifier.certify(
        entityName: 'Login',
        projectRoot: flutterFixture,
        outputDir: p.join(flutterFixture, 'lib', 'src'),
      );

      expect(outcome.certified, isTrue);
      final source = outcome.contractTestSource!;
      expect(
        source,
        contains("import 'package:flutter_test/flutter_test.dart';"),
      );
      expect(source, isNot(contains("import 'package:test/test.dart';")));

      // The certify command owns this surface end to end: driving the
      // REAL capability entrypoint (exit-code contract) on the fixture
      // with the stub proves the capability consults the factory — the
      // committed contract test lands Flutter-shaped, no receipt lies.
      final plugin = MockPlugin(
        outputDir: p.join(flutterFixture, 'lib', 'src'),
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final previousProbe = MockCertificationSandbox.flutterOnPath;
      MockCertificationSandbox.flutterOnPath = () => false;
      try {
        final code = await CertifyMockCapability(
          plugin,
        ).run(['Login', '--project', flutterFixture]);
        // No Flutter SDK on PATH → the honest degradation: generation-
        // governed exit, nothing certified, nothing written.
        expect(
          code,
          0,
          reason:
              'an unrunnable environment proof is not a '
              'red contract (the spec-1110 precedent)',
        );
        expect(
          File(
            p.join(
              flutterFixture,
              'test',
              'mock',
              'login',
              'login_mock_contract_test.dart',
            ),
          ).existsSync(),
          isFalse,
          reason: 'no unverified contract test is committed',
        );
      } finally {
        MockCertificationSandbox.flutterOnPath = previousProbe;
      }
    });
    test('B7: the Flutter probe is a PATH scan, and a red contract with '
        'the SDK present is still honestly red', () async {
      // The probe seam: a PATH entry holding a flutter executable counts.
      final withFlutter = Directory.systemTemp.createTempSync('zfa_1600_p1_');
      File(
        p.join(withFlutter.path, 'flutter'),
      ).writeAsStringSync('#!/bin/sh\n');
      expect(
        MockCertificationSandbox.flutterExecutableOnPath(
          '/nonexistent-a:/nonexistent-b:${withFlutter.path}',
        ),
        isTrue,
      );
      expect(
        MockCertificationSandbox.flutterExecutableOnPath(
          '/nonexistent-a:/nonexistent-b',
        ),
        isFalse,
        reason: 'no flutter executable anywhere on PATH',
      );
      expect(MockCertificationSandbox.flutterExecutableOnPath(''), isFalse);
      withFlutter.deleteSync(recursive: true);

      // Degradation guard: with the toolchain available, a genuinely red
      // contract is still honestly red — the environment degradation path
      // never masks it.
      final certifier = MockCertifier.forProject(
        flutterFixture,
        sandbox: _StubRedSandbox(methods: const ['get', 'update']),
      );
      final outcome = await certifier.certify(
        entityName: 'Login',
        projectRoot: flutterFixture,
        outputDir: p.join(flutterFixture, 'lib', 'src'),
        rePin: true,
      );
      expect(outcome.certified, isFalse);
      expect(outcome.receipt, isNotNull);
      expect(
        outcome.receipt!.methods.where((m) => m.value),
        isEmpty,
        reason: 'every pinned method is honestly unsatisfied',
      );
    });
  });
}

/// A green proof without executing any toolchain — the render surface is
/// what this file pins.
class _StubGreenSandbox extends MockCertificationSandbox {
  _StubGreenSandbox({required this.methods});

  final List<String> methods;

  @override
  Future<MockCertificationRun> run({
    required String entityName,
    required String projectRoot,
    required String outputDir,
    required String contractTestSource,
    required List<ContractMethod> methods,
    bool verbose = false,
  }) async {
    return MockCertificationRun(
      analyzeIssues: 0,
      analyzeErrors: 0,
      passedTests: [for (final m in methods) m.name],
      failedTests: const [],
      methodOutcomes: {for (final m in methods) m.name: true},
      runner: 'stub',
      logs: const ['stub: green proof (render-surface pin)'],
    );
  }
}

/// A honestly-red proof without executing any toolchain — the degradation
/// path must never mask a real red.
class _StubRedSandbox extends MockCertificationSandbox {
  _StubRedSandbox({required this.methods});

  final List<String> methods;

  @override
  Future<MockCertificationRun> run({
    required String entityName,
    required String projectRoot,
    required String outputDir,
    required String contractTestSource,
    required List<ContractMethod> methods,
    bool verbose = false,
  }) async {
    return MockCertificationRun(
      analyzeIssues: 0,
      analyzeErrors: 0,
      passedTests: const [],
      failedTests: [for (final m in methods) m.name],
      methodOutcomes: {for (final m in methods) m.name: false},
      runner: 'stub',
      logs: const ['stub: red proof (every pinned method unsatisfied)'],
    );
  }
}
