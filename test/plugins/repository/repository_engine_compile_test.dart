// Spec 1117 (issue #1117) — Repository generator, engine trust tier:
// COMPILE bar.
//
// The engine preset's repository pair (interface + data implementation +
// the datasource interface it delegates to) must analyze with zero
// errors inside a self-contained pure-Dart fixture package, for the
// FULL engine method set — including `update`, whose `LoginPatch` type
// is the zorphy build product (hand-defined here as the fixture's
// pre-existing state, mirroring `zfa entity create --build`).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(name: 'repo_engine_compile_fixture');

    // The entity + its zorphy patch type at the canonical entity paths.
    await fx.write(
      'lib/src/domain/entities/login/login.dart',
      'class Login {\n'
          '  final String id;\n'
          '  const Login({required this.id});\n'
          '}\n'
          '\n'
          '// The zorphy-generated patch type (build_runner product in real\n'
          '// projects; hand-defined here as the fixture\'s pre-existing state).\n'
          'class LoginPatch {\n'
          '  const LoginPatch();\n'
          '}\n',
    );

    await RepositoryPlugin(
      outputDir: fx.libSrc,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Login',
        domain: 'auth',
        methods: const ['get', 'getList', 'create', 'update', 'delete'],
        generateDataSource: true,
        outputDir: fx.libSrc,
      ),
    );

    await fx.pubGet();
  });

  tearDownAll(() async {
    await fx.dispose();
  });

  test('the engine-method-set repository pair passes dart analyze with zero '
      'errors', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the engine trust-tier Repository output must compile in a '
          'consumer package (interface + impl + datasource + patch '
          'shape).\n${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
