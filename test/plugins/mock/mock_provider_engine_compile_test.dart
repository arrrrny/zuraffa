// Spec 1117 (issue #1117) — MockProvider generator, engine trust tier:
// COMPILE bar.
//
// The generated AuthMockProvider (plus the mock-data files it imports
// and the simulation DI binding emitted alongside it) must analyze with
// zero errors inside a self-contained pure-Dart fixture package.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(name: 'mock_engine_compile_fixture');
    await writeLoginPilotEntities(fx);

    final opts = const GeneratorOptions(dryRun: false, force: false);
    final serviceConfig = GeneratorConfig(
      name: 'Login',
      domain: 'auth',
      service: 'Auth',
      paramsType: 'LoginParams',
      returnsType: 'AuthSession',
      outputDir: fx.libSrc,
    );
    await ServicePlugin(
      outputDir: fx.libSrc,
      options: opts,
    ).generate(serviceConfig);

    // Fixture pre-existing state: the mock-data pair the provider
    // imports (target entity + params entity), hand-augmented with the
    // #1034 selector so the compile bar covers the selector-threaded
    // body too.
    await fx.write(
      'lib/src/data/mock/auth_session_mock_data.dart',
      "import '../../domain/entities/auth_session/auth_session.dart';\n"
          'class AuthSessionMockData {\n'
          "  static const _adminSession = AuthSession(token: 'admin-token');\n"
          "  static const _guestSession = AuthSession(token: 'guest-token');\n"
          "  static const _defaultSession = AuthSession(token: 'default-token');\n"
          '  static AuthSession get sampleAuthSession => _defaultSession;\n'
          '  static List<AuthSession> get sampleList => [_defaultSession];\n'
          '  static AuthSession forMethod(String kind) {\n'
          '    switch (kind) {\n'
          "      case 'admin':\n"
          '        return _adminSession;\n'
          "      case 'guest':\n"
          '        return _guestSession;\n'
          '      default:\n'
          '        return _defaultSession;\n'
          '    }\n'
          '  }\n'
          '}\n',
    );
    await fx.write(
      'lib/src/data/mock/login_params_mock_data.dart',
      "import '../../domain/entities/login_params/login_params.dart';\n"
          'class LoginParamsMockData {\n'
          "  static const _admin = LoginParams(kind: 'admin');\n"
          "  static const _guest = LoginParams(kind: 'guest');\n"
          '  static LoginParams get sampleLoginParams => _admin;\n'
          '  static List<LoginParams> get sampleList => [_admin, _guest];\n'
          '}\n',
    );

    await MockPlugin(outputDir: fx.libSrc, options: opts).generate(
      GeneratorConfig(
        name: 'Login',
        domain: 'auth',
        service: 'Auth',
        methods: const [],
        useCaseType: 'usecase',
        generateMock: true,
        generateData: true,
        paramsType: 'LoginParams',
        returnsType: 'AuthSession',
        outputDir: fx.libSrc,
      ),
    );

    await fx.pubGet();
  });

  tearDownAll(() async {
    await fx.dispose();
  });

  test('the generated AuthMockProvider + mock data + simulation binding pass '
      'dart analyze with zero errors', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the engine trust-tier MockProvider output must compile in a '
          'consumer package.\n${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
