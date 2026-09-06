// Bug 1198 (part of #908 P0) — template self-hosting: `di` template.
//
// Full trust-tier loop against the fixture entity: structural + compile +
// behavioral (the GENERATED registration wiring EXECUTES against the real
// GetIt runtime — register, resolve, #1102 re-setup idempotence) +
// byte-stability diff guard.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory fixture;
  late Directory bare;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await createPureDartFixture('di', repoRoot);
    bare = await createTempFixture('di_bare');
    await writeFixtureEntity(bare);
  });

  tearDownAll(() async {
    if (fixture.existsSync()) fixture.delete(recursive: true);
    if (bare.existsSync()) bare.delete(recursive: true);
  });

  /// The di template wires the datasource + repository artifacts — the
  /// same surface `zfa make --di` drives (make-pipeline parity).
  Future<List<({String path, String? content})>> generateInto(
    Directory root,
  ) async {
    final generated = <({String path, String? content})>[];
    final out = p.join(root.path, 'lib', 'src');
    for (final files in [
      await DataSourcePlugin(
        outputDir: out,
        options: kSelfHostOptions,
      ).generate(
        GeneratorConfig(
          name: kFixtureEntityName,
          methods: const ['get'],
          generateData: true,
          outputDir: out,
        ),
      ),
      await RepositoryPlugin(
        outputDir: out,
        options: kSelfHostOptions,
      ).generate(
        GeneratorConfig(
          name: kFixtureEntityName,
          methods: const ['get'],
          generateRepository: true,
          generateData: true,
          outputDir: out,
        ),
      ),
      await DiPlugin(outputDir: out, options: kSelfHostOptions).generate(
        GeneratorConfig(
          name: kFixtureEntityName,
          methods: const ['get'],
          generateData: true,
          generateDi: true,
          outputDir: out,
        ),
      ),
    ]) {
      generated.addAll(files.map((f) => (path: f.path, content: f.content)));
    }
    return generated;
  }

  group('structural', () {
    test(
      'emits per-artifact registrations + setupDependencies index',
      () async {
        final files = await generateInto(bare);
        final paths = files.map((f) => f.path).toSet();
        expect(
          paths,
          containsAll(<Matcher>[
            contains('di/datasources/product_remote_datasource_di.dart'),
            contains('di/repositories/product_repository_di.dart'),
            contains('di/index.dart'),
          ]),
        );

        final index = files
            .firstWhere((f) => f.path.endsWith('di/index.dart'))
            .content!;
        expect(index, contains('void setupDependencies(GetIt getIt)'));
        // #1102: unregister-first idempotence hooks.
        expect(index, contains('void resetDependencies(GetIt getIt)'));
      },
    );
  });

  group('compile', () {
    test('generated DI wiring analyzes clean in the fixture', () async {
      await generateInto(fixture);
      expectAnalyzerClean(await analyzeFixture(fixture), context: 'di');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('behavioral', () {
    test('generated setupDependencies executes, resolves, and is '
        'idempotent (#1102)', () async {
      await generateInto(fixture);

      final script = File(p.join(fixture.path, 'tool', 'behavior_check.dart'));
      await script.parent.create(recursive: true);
      await script.writeAsString('''
// Bug 1198 behavioral tier — executes the GENERATED DI wiring against the
// real GetIt runtime exported by zuraffa core: register, resolve, and the
// #1102 callable-twice contract.
import 'package:zuraffa/zuraffa.dart';

import '../lib/src/data/datasources/product/product_remote_datasource.dart';
import '../lib/src/data/repositories/data_product_repository.dart';
import '../lib/src/domain/repositories/product_repository.dart';
import '../lib/src/di/index.dart';

Future<void> main() async {
  final getIt = GetIt.instance;

  // First setup registers everything.
  setupDependencies(getIt);
  if (!getIt.isRegistered<ProductRemoteDataSource>()) {
    throw StateError('behavior check failed: remote datasource not '
        'registered by generated DI');
  }
  if (!getIt.isRegistered<ProductRepository>()) {
    throw StateError('behavior check failed: repository not registered '
        'by generated DI');
  }

  // Resolution returns the generated implementation graph.
  final repository = getIt<ProductRepository>();
  if (repository is! DataProductRepository) {
    throw StateError('behavior check failed: repository bound to '
        '\${repository.runtimeType}, expected DataProductRepository');
  }

  // #1102: setupDependencies is callable twice.
  setupDependencies(getIt);
  if (!getIt.isRegistered<ProductRepository>()) {
    throw StateError('behavior check failed: second setup did not '
        're-register (idempotence broken)');
  }

  resetDependencies(getIt);
  // get_it's reset() is async; give it a beat before asserting.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  if (getIt.isRegistered<ProductRepository>()) {
    throw StateError('behavior check failed: resetDependencies left the '
        'repository registered');
  }
}
''');
      final run = await runBehaviorScript(fixture, script.path);
      expect(
        run.exitCode,
        0,
        reason:
            'generated DI wiring must EXECUTE (behavioral tier):\n'
            '${run.stdout}\n${run.stderr}',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(template: 'di', generate: generateInto);
      },
    );
  });
}
