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
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/models/generated_file.dart';
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
class AuthRequest {
  final String email;

  const AuthRequest({required this.email});
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

  Future<ExecutionResult> runServiceModeMock() async {
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
        contains('auth_request_mock_data.dart'),
        reason: 'precondition: the provider is the side that emits the import',
      );
      expect(
        paths.any((x) => x.endsWith('data/mock/auth_request_mock_data.dart')),
        isTrue,
        reason:
            'the provider imports the params fixture, so the same run must '
            'emit it (issue #1735)',
      );
    },
  );
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
