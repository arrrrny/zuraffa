// Issue #1735 — `zfa mock create` in SERVICE mode emitted fixture files whose
// imports did not resolve, so `dart analyze` on the run's own artifacts was red:
//
//  1. every enum-bearing fixture hardcoded
//     `import '../../domain/entities/enums/index.dart'`, a barrel that only
//     exists when the enum happens to live under `domain/entities/enums/`;
//     the issue's enum is declared in its own per-entity folder, per the
//     layout `EntityAnalyzer.isEnum` already probes;
//  2. the provider imported `../../mock/<params>_mock_data.dart` while the same
//     run never generated that file.
//
// The bar is the issue's own Expected section: every file the run emits
// resolves — no depend on the app happening to carry the missing pieces.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/transaction/generation_transaction.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_provider_builder.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/create_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

const _enumSource = '''
enum AuthenticationMethod {
  password,
  biometric,
}
''';

const _loginResponseSource = '''
import '../authentication_method/authentication_method.dart';

class LoginResponse {
  final String token;
  final AuthenticationMethod method;

  const LoginResponse({required this.token, required this.method});
}
''';

const _authRequestSource = '''
import '../authentication_method/authentication_method.dart';

class AuthRequest {
  final String email;
  final AuthenticationMethod method;

  const AuthRequest({required this.email, required this.method});
}
''';

const _authServiceSource = '''
import '../entities/auth_request/auth_request.dart';
import '../entities/login_response/login_response.dart';

abstract class AuthService {
  Future<LoginResponse> login(AuthRequest params);
}
''';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_1735_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    _write(
      outputDir,
      'domain/entities/authentication_method/authentication_method.dart',
      _enumSource,
    );
    _write(
      outputDir,
      'domain/entities/login_response/login_response.dart',
      _loginResponseSource,
    );
    _write(
      outputDir,
      'domain/entities/auth_request/auth_request.dart',
      _authRequestSource,
    );
    _write(outputDir, 'domain/services/auth_service.dart', _authServiceSource);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.delete(recursive: true);
    }
  });

  Future<ExecutionResult> runServiceModeMock([
    Map<String, Object> overrides = const {},
  ]) async {
    final plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );
    return CreateMockCapability(plugin).execute({
      'name': 'Auth',
      'service': 'AuthService',
      'domain': 'auth',
      'params': 'AuthRequest',
      'returns': 'LoginResponse',
      'methods': const <String>[],
      'force': true,
      ...overrides,
    });
  }

  test(
    'issue #1735: every import in the emitted mock/provider files resolves',
    () async {
      final result = await runServiceModeMock();
      expect(result.success, isTrue, reason: result.message);

      final generated = (result.data?['generatedFiles'] as List<dynamic>)
          .cast<GeneratedFile>();
      expect(generated, isNotEmpty);

      // The loop writes as a side effect of asking for a fixture, so a
      // duplicated path means the same file was written twice — harmless on
      // the direct-write path, a `Multiple operations` transaction conflict
      // (and a failed commit) when the run is wrapped in one. The shared
      // `AuthenticationMethod` field makes two fixture types contend for one
      // nested fixture, which is how the second half of that bug shows.
      final paths = generated
          .map((f) => f.path)
          .where((x) => x.isNotEmpty)
          .toList();
      expect(
        paths.toSet().length,
        paths.length,
        reason:
            'emitted twice: '
            '${paths.where((x) => paths.where((y) => y == x).length > 1).toSet()}',
      );

      final unresolved = <String>[];
      for (final file in generated) {
        for (final import in _relativeImports(file.content ?? '')) {
          final target = p.normalize(p.join(p.dirname(file.path), import));
          if (!File(target).existsSync()) {
            unresolved.add(
              '${p.relative(file.path, from: outputDir)} -> $import',
            );
          }
        }
      }

      expect(
        unresolved,
        isEmpty,
        reason:
            'the run emitted imports that resolve to nothing on disk, so '
            '`dart analyze` on its own output is red (issue #1735):\n'
            '${unresolved.join('\n')}',
      );
    },
  );

  test(
    'issue #1735: no emitted file imports a nonexistent entities/enums barrel',
    () async {
      final result = await runServiceModeMock();
      final generated = (result.data?['generatedFiles'] as List<dynamic>)
          .cast<GeneratedFile>();

      final offenders = generated
          .where((f) => (f.content ?? '').contains('entities/enums/index.dart'))
          .map((f) => p.relative(f.path, from: outputDir))
          .toList();

      expect(
        File(
          p.join(outputDir, 'domain', 'entities', 'enums', 'index.dart'),
        ).existsSync(),
        isFalse,
        reason:
            'precondition: this fixture declares its enum in a per-entity '
            'folder, so no enums barrel exists to import',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'these artifacts import a barrel this project does not have:\n'
            '${offenders.join('\n')}',
      );
    },
  );

  test(
    'issue #1735: the params fixture the provider imports is generated',
    () async {
      final result = await runServiceModeMock();
      final generated = (result.data?['generatedFiles'] as List<dynamic>)
          .cast<GeneratedFile>();
      final paths = generated.map((f) => f.path).toSet();

      final provider = generated.firstWhere(
        (f) => f.path.endsWith('data/providers/auth/auth_mock_provider.dart'),
        orElse: () => throw StateError(
          'no mock provider emitted; generated: '
          '${generated.map((f) => p.relative(f.path, from: outputDir)).join(', ')}',
        ),
      );

      expect(
        provider.content ?? '',
        isNot(contains('auth_request_mock_data.dart')),
        reason:
            'issue #1798: the provider must not import the params mock-data '
            'file it never references',
      );
      expect(
        paths.any((x) => x.endsWith('data/mock/auth_request_mock_data.dart')),
        isTrue,
        reason:
            'the params fixture is still emitted for other consumers (issue #1735)',
      );
    },
  );

  test(
    'issue #1735: a primitive --returns still emits the params fixture',
    () async {
      // The fixture config used to inherit the service's `returnsType` /
      // `useCaseType`, and service mode is always `isCustomUseCase`, so a
      // primitive `--returns` short-circuited `generateMockDataFile` to an
      // empty path: the provider imported the params fixture and no file was
      // written, with the run still reporting success.
      final result = await runServiceModeMock(const {'returns': 'String'});
      expect(result.success, isTrue, reason: result.message);

      final generated = (result.data?['generatedFiles'] as List<dynamic>)
          .cast<GeneratedFile>();
      final paths = generated.map((f) => f.path).toSet();

      final provider = generated.firstWhere(
        (f) => f.path.endsWith('data/providers/auth/auth_mock_provider.dart'),
        orElse: () => throw StateError(
          'no mock provider emitted; generated: '
          '${generated.map((f) => p.relative(f.path, from: outputDir)).join(', ')}',
        ),
      );

      expect(
        provider.content ?? '',
        isNot(contains('auth_request_mock_data.dart')),
        reason:
            'issue #1798: the provider must not import the params mock-data '
            'file it never references, even with a primitive return type',
      );
      expect(
        paths.any((x) => x.endsWith('data/mock/auth_request_mock_data.dart')),
        isTrue,
        reason:
            'a primitive return type must not suppress the params fixture (issue #1735)',
      );
    },
  );

  test(
    'issue #1735: the service-mode run commits inside one transaction',
    () async {
      // `make … --with mock` wraps every plugin in a GenerationTransaction,
      // where two operations for one path fail validation ("Multiple
      // operations for …"). The run's own fixture writes used to produce
      // exactly that — silently absorbed by `zfa mock create`'s direct
      // writes, fatal here.
      final transaction = GenerationTransaction(dryRun: false, force: true);
      final result = await GenerationTransaction.run(
        transaction,
        runServiceModeMock,
      );
      expect(result.success, isTrue, reason: result.message);

      final commit = await transaction.commit(FileSystem.create());
      expect(
        commit.conflicts,
        isEmpty,
        reason:
            'the run emitted two operations for one path:\n'
            '${commit.conflicts.join('\n')}',
      );
      expect(commit.success, isTrue);
    },
  );

  test('issue #1735: the appendToExisting path resolves its import like the '
      'create path', () async {
    // The append branch kept the hardcoded
    // `domain/entities/<snake>/<snake>.dart` this PR removed from the
    // create path, so a type declared anywhere else — an enum in the
    // conventional barrel, say — got a URI that does not resolve.
    _write(
      outputDir,
      'domain/entities/enums/index.dart',
      'enum SessionState {\n  active,\n  expired,\n}\n',
    );
    _write(outputDir, 'domain/services/session_service.dart', '''
import '../entities/enums/index.dart';

abstract class SessionService {
  Future<void> store(SessionState params);
}
''');
    _write(outputDir, 'data/providers/session/session_mock_provider.dart', '''
// GENERATED - DO NOT EDIT
// Generated by zfa for: Session
import 'dart:async';

import 'package:zuraffa/mock.dart';

import '../../../domain/services/session_service.dart';

/// Mock provider for SessionService
class SessionMockProvider
    with Loggable, FailureHandler
    implements SessionService {
  SessionMockProvider([Duration? delay])
    : _delay = delay ?? const Duration(milliseconds: 100);

  final Duration _delay;
}

// END GENERATED
''');

    final file = await MockProviderBuilder(outputDir: outputDir)
        .generateMockProvider(
          GeneratorConfig(
            name: 'Session',
            service: 'SessionService',
            domain: 'session',
            paramsType: 'SessionState',
            appendToExisting: true,
            outputDir: outputDir,
          ),
        );

    expect(
      file.content ?? '',
      contains("import '../../../domain/entities/enums/index.dart';"),
      reason:
          'the appended import must point at the enum declaration, not the '
          'per-entity folder this project does not have (issue #1735)',
    );
  });
}

void _write(String outputDir, String relativePath, String content) {
  final file = File(p.join(outputDir, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Every `import '<relative>';` in [source], in declaration order.
List<String> _relativeImports(String source) {
  final matches = RegExp(
    r"""^\s*import\s+'([^']+)';""",
    multiLine: true,
  ).allMatches(source);
  return matches
      .map((m) => m.group(1)!)
      .where((uri) => uri.startsWith('.'))
      .toList();
}
