import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

/// Regression guard for issue #2141.
///
/// `zfa make SchedulePriceCheck --provider --params=NoParams
/// --returns=void --type=completable --domain=price_check --no-entity`
/// exited non-zero with
///   "For completable usecases, you must specify a repository or service
///    using --repo or --service. Only --type=sync allows no dependencies."
/// even though the matching `SchedulePriceCheckService` interface already
/// existed on disk. The completable provider path required an explicit
/// dependency binding instead of inferring the generated service from the
/// target name.
///
/// The fix infers the feature's own `<Name>Service` (the same surface a bare
/// `--service` selects) when a non-sync custom usecase names no explicit
/// dependency, and lets the existing interface/method resolution verify it
/// exists — mirroring the service interface it is generated against.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue_2141_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    final serviceDir = Directory(p.join(outputDir, 'domain', 'services'));
    await serviceDir.create(recursive: true);
    await File(
      p.join(serviceDir.path, 'schedule_price_check_service.dart'),
    ).writeAsString(
      'abstract class SchedulePriceCheckService {\n'
      '  Future<void> schedulePriceCheck(NoParams params);\n'
      '}',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('completable usecase infers the existing <Name>Service when no '
      'dependency is given', () async {
    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    // Mirrors: zfa make SchedulePriceCheck --with=usecase --type=completable
    //   --domain=price_check --no-entity  (no --repo, no --service).
    final files = await plugin.generate(
      GeneratorConfig(
        name: 'SchedulePriceCheck',
        useCaseType: 'completable',
        domain: 'price_check',
        paramsType: 'NoParams',
        returnsType: 'void',
        noEntity: true,
        outputDir: outputDir,
      ),
    );

    expect(files, isNotEmpty, reason: 'a usecase file must be generated');
    final content = files.first.content ?? '';
    expect(content, contains('class SchedulePriceCheckUseCase'));
    expect(content, contains('CompletableUseCase<NoParams>'));
    expect(
      content,
      contains('final SchedulePriceCheckService _schedulePriceCheckService;'),
      reason: 'the inferred service interface is injected as a dependency',
    );
    expect(
      content,
      contains('SchedulePriceCheckUseCase(this._schedulePriceCheckService);'),
    );
    expect(
      content,
      contains(
        'return await _schedulePriceCheckService'
        '.schedulePriceCheck(params);',
      ),
    );
  });

  test('completable usecase still refuses when no matching service interface '
      'exists', () async {
    await Directory(
      p.join(outputDir, 'domain', 'services'),
    ).delete(recursive: true);

    final plugin = UseCasePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    expect(
      () => plugin.generate(
        GeneratorConfig(
          name: 'SchedulePriceCheck',
          useCaseType: 'completable',
          domain: 'price_check',
          paramsType: 'NoParams',
          returnsType: 'void',
          noEntity: true,
          outputDir: outputDir,
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('service interface not found'),
            contains('SchedulePriceCheckService'),
          ),
        ),
      ),
      reason:
          'inference must fail loudly (never generate a use case that '
          'cannot compile) when the interface is absent',
    );
  });
}
