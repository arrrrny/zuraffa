// Spec 1117 (issue #1117) — DataSource generator, engine trust tier:
// COMPILE bar.
//
// The engine preset's datasource pair (interface + remote
// implementation, full engine method set including the update/patch
// member) must analyze with zero errors inside a self-contained
// pure-Dart fixture package — the datasource is the seam the repository
// implementation delegates to, so a compile regression here breaks every
// engine slice.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(name: 'ds_engine_compile_fixture');

    // The entity (+ zorphy patch type) so the interface's entity import
    // resolves (issue #942: the entity import is emitted only when the
    // entity file exists at generation time).
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

    await DataSourcePlugin(
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

  test('the engine-method-set datasource pair passes dart analyze with zero '
      'errors', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the engine trust-tier DataSource output must compile in a '
          'consumer package.\n${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
