// Issue #1322 — `zfa tdd make` grades a failed plan `build` step whose
// output carries the missing-builder-dependency class with the distinct
// `missing-builder-dependency` outcome (NOT the generic
// `generation-error`), naming the package and prescribing the exact fix.
//
// Unit tier: the @visibleForTesting classifier seam is driven directly
// (the full make pipeline spawns real build_runner; the classifier is the
// decision this spec owns).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/commands/make_command.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('zfa_1322_make_');
  });

  tearDown(() {
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  Future<void> seedPackageConfig(List<String> packages) async {
    final dartTool = Directory(p.join(sandbox.path, '.dart_tool'));
    await dartTool.create(recursive: true);
    final entries = packages
        .map((n) => '{"name":"$n","rootUri":"../"}')
        .join(',');
    await File(
      p.join(dartTool.path, 'package_config.json'),
    ).writeAsString('{"configVersion":2,"packages":[$entries]}');
  }

  GenerationStep failedBuildStep(String output) => GenerationStep(
    command: 'zfa build',
    exitCode: 1,
    output: output,
    purpose: 'build generated code',
  );

  test('1322: a failed build step carrying the unknown-builder signal in a '
      'project missing zorphy → missingBuilderDependency', () async {
    await seedPackageConfig(['test', 'json_serializable', 'source_gen']);
    final missing = MakeCommand.missingBuildersForBuildStep(
      step: failedBuildStep(
        '[WARNING] Ignoring options for unknown builder "zorphy:zorphy" '
        'found in build.yaml.',
      ),
      stepArgs: const ['build'],
      projectRoot: sandbox.path,
    );
    expect(missing, isNotNull);
    expect(missing!.map((b) => b.package), contains('zorphy'));
  });

  test('1322: an unclassified build failure (everything resolvable) → null '
      '— the existing generation-error grading stands', () async {
    await seedPackageConfig([
      'test',
      'json_serializable',
      'source_gen',
      'zorphy',
    ]);
    expect(
      MakeCommand.missingBuildersForBuildStep(
        step: failedBuildStep('some other build failure'),
        stepArgs: const ['build'],
        projectRoot: sandbox.path,
      ),
      isNull,
    );
  });

  test('1322: missing packages in the graph but the failure output does NOT '
      'link the failure to the builder (a generic build_runner failure, the '
      'U-991b class) → null — the static state alone cannot attribute an '
      'unrelated failure', () async {
    await seedPackageConfig(['test', 'json_serializable', 'source_gen']);
    expect(
      MakeCommand.missingBuildersForBuildStep(
        step: failedBuildStep('build_runner exited 1'),
        stepArgs: const ['build'],
        projectRoot: sandbox.path,
      ),
      isNull,
    );
  });

  test('1322: the #276 safety-net marker in the child output links the '
      'failure to the missing builder (the child zfa build failed through '
      'the safety net)', () async {
    await seedPackageConfig(['test', 'json_serializable', 'source_gen']);
    final missing = MakeCommand.missingBuildersForBuildStep(
      step: failedBuildStep(
        '❌ build_runner wrote 0 outputs although @Zorphy sources exist.\n'
        '   The builder package(s) zorphy (registered in build.yaml as '
        'zorphy:zorphy) are NOT in the dependency graph — fix: '
        '`dart pub add --dev zorphy`',
      ),
      stepArgs: const ['build'],
      projectRoot: sandbox.path,
    );
    expect(missing, isNotNull);
    expect(missing!.map((b) => b.package), contains('zorphy'));
  });

  test('1322: only build steps classify — a non-build step → null', () async {
    await seedPackageConfig(['test']);
    expect(
      MakeCommand.missingBuildersForBuildStep(
        step: failedBuildStep(
          '[WARNING] Ignoring options for unknown builder "zorphy:zorphy" '
          'found in build.yaml.',
        ),
        stepArgs: const ['tdd', 'wire', 'B-001'],
        projectRoot: sandbox.path,
      ),
      isNull,
    );
  });

  test('1322: label vocabulary — the outcome label is the kebab-case '
      'missing-builder-dependency', () {
    expect(
      MakeOutcome.missingBuilderDependency.label,
      'missing-builder-dependency',
    );
  });
}
