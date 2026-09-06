// Spec 1117 (issue #1117) — MockProvider generator, engine trust tier:
// STRUCTURAL bar.
//
// The 005-login-engine pilot's AuthMockProvider "worked" — by luck, not
// by test. This suite pins the generated shape for the pilot's config:
// class name, implements clause, the certified 100 ms delay constructor
// default, imports, and the expected stub body — including the #1034
// per-method fixture selector threading (the regression the spec's
// success criteria demand be caught).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_mock_struct_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    await _writeEntity(outputDir, 'auth_session', 'AuthSession');
    await _writeEntity(outputDir, 'login_params', 'LoginParams');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// The pilot's mock config: the mock provider for the login
  /// vertical's AuthService.
  GeneratorConfig mockConfig(String dir) => GeneratorConfig(
    name: 'Login',
    domain: 'auth',
    service: 'Auth',
    methods: const [],
    useCaseType: 'usecase',
    generateMock: true,
    generateData: true,
    paramsType: 'LoginParams',
    returnsType: 'AuthSession',
    outputDir: dir,
  );

  Future<String> generateProvider({
    required String mockDataSource,
    bool force = false,
  }) async {
    final opts = GeneratorOptions(dryRun: false, force: force);
    // The service interface the provider implements.
    await ServicePlugin(outputDir: outputDir, options: opts).generate(
      GeneratorConfig(
        name: 'Login',
        domain: 'auth',
        service: 'Auth',
        paramsType: 'LoginParams',
        returnsType: 'AuthSession',
        outputDir: outputDir,
      ),
    );
    // The mock-data class the provider's canned values come from — the
    // sanctioned AUGMENTED escape hatch surface (#1034: values are
    // hand-augmentable; provider ROUTING stays 100% generated).
    await _write(
      p.join(outputDir, 'data', 'mock', 'auth_session_mock_data.dart'),
      mockDataSource,
    );
    // The params entity's mock data — fixture pre-existing state that
    // satisfies the provider's entity-graph import.
    await _write(
      p.join(outputDir, 'data', 'mock', 'login_params_mock_data.dart'),
      "import '../../domain/entities/login_params/login_params.dart';\n"
      'class LoginParamsMockData {\n'
      "  static const _admin = LoginParams(kind: 'admin');\n"
      "  static const _guest = LoginParams(kind: 'guest');\n"
      '  static LoginParams get sampleLoginParams => _admin;\n'
      '  static List<LoginParams> get sampleList => [_admin, _guest];\n'
      '}\n',
    );
    final files = await MockPlugin(
      outputDir: outputDir,
      options: opts,
    ).generate(mockConfig(outputDir));
    final provider = files.firstWhere(
      (f) => f.type == 'mock_provider',
      orElse: () => throw StateError(
        'the mock provider was not generated. Files: '
        '${files.map((f) => f.path)}',
      ),
    );
    // The on-disk file is the artifact the engine receipt certifies.
    return File(provider.path).readAsStringSync();
  }

  test('generates AuthMockProvider implementing the service with the '
      'certified 100 ms delay default and the expected stub body', () async {
    final content = await generateProvider(mockDataSource: _mockDataNoSelector);

    // Class + contract: implements the service the DI binds it to.
    expect(
      content,
      contains(
        'class AuthMockProvider with Loggable, FailureHandler '
        'implements AuthService {',
      ),
      reason: 'the provider must implement the service interface',
    );
    // THE certified delay default: 100 ms when the parameter is null.
    expect(
      content,
      contains('AuthMockProvider([Duration? delay])'),
      reason:
          'the delay constructor parameter must be positional '
          'optional',
    );
    expect(
      content,
      contains('_delay = delay ?? const Duration(milliseconds: 100);'),
      reason: 'the default delay must be the certified 100 ms',
    );
    expect(
      content,
      contains('final Duration _delay;'),
      reason: 'the delay field must back every stub body',
    );
    // Imports: the native-mock marker, the service, the entities.
    expect(
      content,
      contains("import 'dart:async';"),
      reason: 'Future.delayed needs dart:async',
    );
    expect(
      content,
      contains("import 'package:zuraffa/mock.dart';"),
      reason: 'the canonical zuraffa-native mock marker import',
    );
    expect(
      content,
      contains("import '../../../domain/services/auth_service.dart';"),
      reason: 'the provider imports the service it implements',
    );
    expect(
      content,
      contains(
        "import '../../../domain/entities/auth_session/auth_session.dart';",
      ),
      reason: 'the returns entity import must resolve',
    );
    // The expected stub body: log, honor the delay, return the canned
    // fixture.
    expect(
      content,
      contains('Future<AuthSession> login(LoginParams params) async {'),
      reason: 'the stub must match the service method signature',
    );
    expect(
      content,
      contains("logger.info('login called with params: \$params');"),
      reason: 'the stub body logs the call',
    );
    expect(
      content,
      contains('await Future.delayed(_delay);'),
      reason: 'the stub body must honor the delay',
    );
    expect(
      content,
      contains('return AuthSessionMockData.sampleAuthSession;'),
      reason:
          'the stub body returns the single-fixture canned value '
          'when no selector is declared',
    );
  });

  test(
    '#1034: threads the per-method fixture selector '
    '(AuthSessionMockData.forMethod(params.kind)) when the mock data '
    'class declares one and the params entity carries the discriminator',
    () async {
      final content = await generateProvider(
        mockDataSource: _mockDataWithSelector,
      );

      expect(
        content,
        contains('return AuthSessionMockData.forMethod(params.kind);'),
        reason:
            'issue #1034: the stub body must route through the declared '
            'per-method fixture selector (the discriminator field of the '
            'params entity) instead of the single-fixture sample getter',
      );
      expect(
        content,
        isNot(contains('return AuthSessionMockData.sampleAuthSession;')),
        reason:
            'the single-fixture shape must be replaced, not '
            'duplicated, when the selector is threaded',
      );
    },
  );
}

String get _mockDataNoSelector => '''
import '../../domain/entities/auth_session/auth_session.dart';

/// Mock data for AuthSession (no per-method selector declared: the
/// provider keeps the single-fixture shape).
class AuthSessionMockData {
  static const _defaultSession = AuthSession(token: 'default-token');
  static AuthSession get sampleAuthSession => _defaultSession;
  static List<AuthSession> get sampleList => [_defaultSession];
}
''';

String get _mockDataWithSelector => '''
import '../../domain/entities/auth_session/auth_session.dart';

/// Mock data for AuthSession, hand-augmented with the #1034 per-method
/// fixture selector (the sanctioned AUGMENTED escape hatch: mock-data
/// VALUES may be hand-written; provider routing stays generated).
class AuthSessionMockData {
  static const _adminSession = AuthSession(token: 'admin-token');
  static const _guestSession = AuthSession(token: 'guest-token');
  static const _defaultSession = AuthSession(token: 'default-token');
  static AuthSession get sampleAuthSession => _defaultSession;
  static List<AuthSession> get sampleList => [_defaultSession];
  static AuthSession forMethod(String kind) {
    switch (kind) {
      case 'admin':
        return _adminSession;
      case 'guest':
        return _guestSession;
      default:
        return _defaultSession;
    }
  }
}
''';

Future<void> _writeEntity(
  String outputDir,
  String snake,
  String className,
) async {
  await _write(
    p.join(outputDir, 'domain', 'entities', snake, '$snake.dart'),
    'class $className {\n'
    '  final String ${snake == 'login_params' ? 'kind' : 'token'};\n'
    '  const $className({required this.${snake == 'login_params' ? 'kind' : 'token'}});\n'
    '}\n',
  );
}

Future<void> _write(String path, String content) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
