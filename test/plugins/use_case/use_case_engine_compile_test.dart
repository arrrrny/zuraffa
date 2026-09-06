// Spec 1117 (issue #1117) — UseCase generator, engine trust tier:
// COMPILE bar.
//
// The generated LoginUseCase + its backing AuthService must analyze with
// ZERO ERRORS inside a self-contained pure-Dart fixture package that
// depends on this repo — the same bar the existing trust-tier compile
// gates apply (`usecase_compile_test.dart`, spec 077/T012), extended to
// the pilot's custom-usecase shape (service-backed, not entity-backed).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(name: 'uc_engine_compile_fixture');
    await writeLoginPilotEntities(fx);

    // The engine chain for the login vertical: the service interface
    // first, then the custom usecase that imports and calls it.
    final config = GeneratorConfig(
      name: 'Login',
      useCaseType: 'usecase',
      domain: 'auth',
      service: 'Auth',
      paramsType: 'LoginParams',
      returnsType: 'AuthSession',
      outputDir: fx.libSrc,
    );
    final opts = const GeneratorOptions(dryRun: false, force: true);
    await ServicePlugin(outputDir: fx.libSrc, options: opts).generate(config);
    await UseCasePlugin(outputDir: fx.libSrc, options: opts).generate(config);

    await fx.pubGet();
  });

  tearDownAll(() async {
    await fx.dispose();
  });

  test('the generated service + usecase pair passes dart analyze with zero '
      'errors', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the engine trust-tier UseCase output must compile in a '
          'consumer package.\n${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
