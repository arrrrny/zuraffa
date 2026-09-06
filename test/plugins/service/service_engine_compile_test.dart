// Spec 1117 (issue #1117) — Service generator, engine trust tier:
// COMPILE bar.
//
// The generated AuthService interface must analyze with zero errors
// inside a self-contained pure-Dart fixture package depending on this
// repo — the service interface is the seam the mock provider implements
// and the usecase calls, so a compile regression here breaks the whole
// engine slice.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(name: 'svc_engine_compile_fixture');
    await writeLoginPilotEntities(fx);

    await ServicePlugin(
      outputDir: fx.libSrc,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Login',
        domain: 'auth',
        service: 'Auth',
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

  test('the generated AuthService interface passes dart analyze with zero '
      'errors', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the engine trust-tier Service output must compile in a '
          'consumer package.\n${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
