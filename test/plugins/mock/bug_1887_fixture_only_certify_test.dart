// Issue #1887: `zfa mock create <Enum> --certify` certified an enum
// against a CRUD datasource the generator deliberately never emits
// (#1037) — an unsatisfiable proof whose printed remedy was the very
// command that had just run. The command now reports an enum as
// certified-with-nothing: the mock data WAS generated, there is no CRUD
// surface to prove (the cited red/green evidence, committed as a test).
//
// The #1887 review widened and re-ordered that treatment; this file pins
// all three of its shapes:
//
// - the shared fixture-only predicate (#1747): a non-enum type whose
//   source declares no CRUD surface (a plain DTO / value class) takes the
//   same certified-with-nothing path, while a SERVICE-mode provider —
//   which implements the service interface, not the entity's CRUD
//   surface — stays certifiable;
// - the ordering in BOTH capabilities: the fixture-only short-circuit
//   runs ABOVE the sandbox/toolchain gates, so an entity with nothing to
//   prove never reports an unresolved environment (a Flutter host
//   without the SDK; a project whose zuraffa root cannot resolve).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/certify_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/create_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certification_sandbox.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_contract_test_writer.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certifier.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

import 'mock_cli_guard.dart';

const _enumSource = 'enum SubscriptionTier { free, pro, enterprise }\n';

/// A hand-written DTO (the #1747 shape): named fields, no `id`, no
/// `copyWithField`, no `<Type>Patch` — no CRUD surface.
const _dtoSource = '''
class LoginResponse {
  final String userId;
  final String displayName;

  const LoginResponse({required this.userId, required this.displayName});
}
''';

const _dartHostPubspec = '''
name: dart_host
environment:
  sdk: ^3.11.0
dependencies:
  http: ^1.2.0
''';

const _flutterHostPubspec = '''
name: flutter_host
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''';

void main() {
  // Captured before any test repoints Directory.current: the fixture's
  // package_config resolves `zuraffa` at this checkout, the "real CLI
  // invocation" shape the sandbox root probe reads.
  final repoRoot = Directory.current.path;

  final fixtures = <Directory>[];

  tearDown(() async {
    for (final dir in fixtures.toList()) {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
    fixtures.clear();
  });

  /// Scaffolds a minimal host project: the enum entity, a CRUD-less DTO,
  /// the given pubspec, and (optionally) a package_config resolving the
  /// zuraffa framework root.
  Future<String> scaffold({
    required String pubspec,
    bool resolvableFrameworkRoot = false,
  }) async {
    final root = await Directory.systemTemp.createTemp('zfa_1887_');
    fixtures.add(root);
    final out = p.join(root.path, 'lib', 'src');
    final enumsDir = Directory(p.join(out, 'domain', 'entities', 'enums'))
      ..createSync(recursive: true);
    File(
      p.join(enumsDir.path, 'subscription_tier.dart'),
    ).writeAsStringSync(_enumSource);
    final dtoDir = Directory(
      p.join(out, 'domain', 'entities', 'login_response'),
    )..createSync(recursive: true);
    File(
      p.join(dtoDir.path, 'login_response.dart'),
    ).writeAsStringSync(_dtoSource);
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(pubspec);
    if (resolvableFrameworkRoot) {
      final dartTool = Directory(p.join(root.path, '.dart_tool'))
        ..createSync(recursive: true);
      File(p.join(dartTool.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'zuraffa', 'rootUri': Uri.file(repoRoot).toString()},
          ],
        }),
      );
    }
    return root.path;
  }

  MockPlugin pluginFor(String project) => MockPlugin(
    outputDir: p.join(project, 'lib', 'src'),
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  group('#1887 review — the shared fixture-only predicate', () {
    test('the certifier certifies an enum as certified-with-nothing '
        '(no receipt, named reason)', () async {
      final project = await scaffold(pubspec: _dartHostPubspec);
      final outcome = await MockCertifier.forProject(project).certify(
        entityName: 'SubscriptionTier',
        projectRoot: project,
        outputDir: p.join(project, 'lib', 'src'),
      );

      expect(outcome.certified, isTrue);
      expect(outcome.receipt, isNull);
      expect(outcome.contractTestSource, isNull);
      expect(
        outcome.logs.join('\n'),
        contains('no CRUD datasource surface to certify'),
      );
    });

    test('a non-enum CRUD-less type (DTO / value class) takes the same '
        'fixture-only path (#1747 alignment)', () async {
      final project = await scaffold(pubspec: _dartHostPubspec);
      final outcome = await MockCertifier.forProject(project).certify(
        entityName: 'LoginResponse',
        projectRoot: project,
        outputDir: p.join(project, 'lib', 'src'),
      );

      expect(
        outcome.certified,
        isTrue,
        reason:
            'pre-fix this was the absent-datasource refusal the '
            'finder quotes — the builder never emits a CRUD surface '
            'for a CRUD-less type',
      );
      expect(outcome.receipt, isNull);
      expect(
        outcome.logs.join('\n'),
        contains('no CRUD datasource surface to certify'),
      );
    });

    test('a service-mode provider stays certifiable (service runs are exempt '
        'from the fixture-only predicate)', () async {
      final project = await scaffold(pubspec: _dartHostPubspec);
      final outcome = await MockCertifier.forProject(project).certify(
        entityName: 'LoginResponse',
        projectRoot: project,
        outputDir: p.join(project, 'lib', 'src'),
        service: 'BillingService',
      );

      expect(
        outcome.certified,
        isFalse,
        reason:
            'service-mode providers implement the service interface, '
            'not the entity CRUD surface — they are a real proof target',
      );
      expect(
        outcome.logs.join('\n'),
        contains('no mock provider'),
        reason:
            'the run proceeds to the provider lookup instead of the '
            'fixture-only short-circuit',
      );
    });
  });

  group('#1887 review — the short-circuit sits above the sandbox gates', () {
    test('zfa mock certify on an enum reports the intended success on a '
        'Flutter host without the SDK', () async {
      final project = await scaffold(pubspec: _flutterHostPubspec);
      final previousProbe = MockCertificationSandbox.flutterOnPath;
      MockCertificationSandbox.flutterOnPath = () => false;
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      int code;
      try {
        code = await IOOverrides.runZoned(
          () => CertifyMockCapability(
            pluginFor(project),
          ).run(['SubscriptionTier', '--project', project]),
          stdout: () => _StringSinkStdout(stdoutBuffer),
          stderr: () => _StringSinkStdout(stderrBuffer),
        );
      } finally {
        MockCertificationSandbox.flutterOnPath = previousProbe;
      }

      expect(code, 0);
      expect(
        stdoutBuffer.toString(),
        contains('no datasource surface to certify'),
        reason:
            'pre-fix the toolchain gate reported the unresolved '
            'environment instead of the fixture-only success',
      );
      expect(
        stderrBuffer.toString(),
        isNot(contains('no flutter executable on PATH')),
      );
    });

    test('zfa mock create <Enum> --certify reports certified-with-nothing '
        'even on a Flutter host without the SDK', () async {
      final project = await scaffold(
        pubspec: _flutterHostPubspec,
        resolvableFrameworkRoot: true,
      );
      final previousCwd = Directory.current;
      final previousProbe = MockCertificationSandbox.flutterOnPath;
      MockCertificationSandbox.flutterOnPath = () => false;
      try {
        final result = await CwdGuard.exclusive(() async {
          Directory.current = project;
          try {
            return await CreateMockCapability(
              pluginFor(project),
            ).execute({'name': 'SubscriptionTier', 'certify': true});
          } finally {
            Directory.current = previousCwd;
          }
        });

        expect(result.success, isTrue);
        expect(
          result.data?['certified'],
          isTrue,
          reason:
              'pre-fix the gate reported certSandboxUnresolved for an '
              'entity that has no proof to run in ANY environment',
        );
        expect(result.data?['certSandboxUnresolved'], isNot(isTrue));
      } finally {
        MockCertificationSandbox.flutterOnPath = previousProbe;
      }
    });

    test('zfa mock create <Enum> --certify succeeds without the absent-'
        'datasource failure and writes no receipt lie', () async {
      final project = await scaffold(
        pubspec: _dartHostPubspec,
        resolvableFrameworkRoot: true,
      );
      final previousCwd = Directory.current;
      final result = await CwdGuard.exclusive(() async {
        Directory.current = project;
        try {
          return await CreateMockCapability(
            pluginFor(project),
          ).execute({'name': 'SubscriptionTier', 'certify': true});
        } finally {
          Directory.current = previousCwd;
        }
      });

      expect(
        result.success,
        isTrue,
        reason:
            'the #1887 red: mock certification failed for the enum with '
            'the absent-datasource error',
      );
      expect(result.message, isNull);
      expect(result.data?['certified'], isTrue);
      expect(
        File(
          p.join(
            project,
            MockContractTestWriter.contractTestPath('SubscriptionTier'),
          ),
        ).existsSync(),
        isFalse,
        reason: 'a fixture-only entity has no contract test to commit',
      );
    });

    test('zfa mock create on a CRUD-less DTO --certify succeeds (the '
        "finder's real-world symptom)", () async {
      final project = await scaffold(
        pubspec: _dartHostPubspec,
        resolvableFrameworkRoot: true,
      );
      final previousCwd = Directory.current;
      final result = await CwdGuard.exclusive(() async {
        Directory.current = project;
        try {
          return await CreateMockCapability(
            pluginFor(project),
          ).execute({'name': 'LoginResponse', 'certify': true});
        } finally {
          Directory.current = previousCwd;
        }
      });

      expect(
        result.success,
        isTrue,
        reason:
            'pre-fix the create path reported the same absent-datasource '
            'failure it once reported for enums',
      );
      expect(result.message, isNull);
      expect(result.data?['certified'], isTrue);
    });
  });
}

/// Minimal [Stdout] adapter so capability prose (written through
/// `stdout.writeln` / `stderr.writeln`) can be captured in-process.
class _StringSinkStdout implements Stdout {
  _StringSinkStdout(this._target);
  final StringBuffer _target;

  @override
  void write(Object? obj) => _target.write(obj);

  @override
  void writeln([Object? obj = '']) => _target.writeln(obj);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _target.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _target.writeCharCode(charCode);

  @override
  bool get hasTerminal => false;

  @override
  IOSink get nonBlocking => throw UnsupportedError('nonBlocking');

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  int get terminalColumns => throw UnsupportedError('terminalColumns');

  @override
  int get terminalLines => throw UnsupportedError('terminalLines');

  @override
  bool get supportsAnsiEscapes => false;

  @override
  String get lineTerminator => '\n';

  @override
  set lineTerminator(String value) {}

  @override
  void add(List<int> data) => _target.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future.value();

  @override
  Future<void> flush() async {}
}
