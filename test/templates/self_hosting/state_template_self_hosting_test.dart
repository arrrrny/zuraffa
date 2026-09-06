// Bug 1198 (part of #908 P0) — template self-hosting: `state` template.
//
// Full trust-tier loop against the fixture entity: structural + compile +
// behavioral (the generated state class EXECUTES: initial state, per-method
// flags, copyWith transitions) + byte-stability diff guard.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';

import '../../helpers/template_self_hosting.dart';

void main() {
  late Directory fixture;
  late Directory bare;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    fixture = await createPureDartFixture('state', repoRoot);
    bare = await createTempFixture('state_bare');
    await writeFixtureEntity(bare);
  });

  tearDownAll(() async {
    if (fixture.existsSync()) fixture.delete(recursive: true);
    if (bare.existsSync()) bare.delete(recursive: true);
  });

  Future<List<({String path, String? content})>> generateInto(
    Directory root,
  ) async {
    final files =
        await StatePlugin(
          outputDir: p.join(root.path, 'lib', 'src'),
          options: kSelfHostOptions,
        ).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateState: true,
            outputDir: p.join(root.path, 'lib', 'src'),
          ),
        );
    return files.map((f) => (path: f.path, content: f.content)).toList();
  }

  group('structural', () {
    test('emits exactly one state file at the canonical path', () async {
      final files = await generateInto(bare);
      expect(files, hasLength(1));
      expect(
        files.single.path,
        contains('presentation/pages/product/product_state.dart'),
      );
    });

    test('declares the fixture-entity state contract', () async {
      final files = await generateInto(bare);
      final content = files.single.content!;
      expect(content, contains('class ProductState {'));
      expect(
        content,
        contains("import '../../../domain/entities/product/product.dart';"),
      );
      expect(content, contains('final Product? product;'));
      expect(content, contains('final List<Product> productList;'));
      expect(content, contains('final bool isGetting;'));
      expect(content, contains('final bool isGettingList;'));
      expect(content, contains('ProductState copyWith({'));
      expect(content, contains('bool get isLoading =>'));
      // Generated-marker envelope: the template is machine-owned output.
      expect(content, contains('// GENERATED - DO NOT EDIT'));
      expect(content, contains('// END GENERATED'));
    });
  });

  group('compile', () {
    test('generated state analyzes clean in the fixture', () async {
      await generateInto(fixture);
      expectAnalyzerClean(await analyzeFixture(fixture), context: 'state');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('behavioral', () {
    test(
      'generated state executes: initial, flags, copyWith transitions',
      () async {
        await generateInto(fixture);

        final script = File(
          p.join(fixture.path, 'tool', 'behavior_check.dart'),
        );
        await script.parent.create(recursive: true);
        await script.writeAsString('''
// Bug 1198 behavioral tier — executes the GENERATED state class: the
// initial state, the per-method loading flags, and copyWith transitions.
import '../lib/src/domain/entities/product/product.dart';
import '../lib/src/presentation/pages/product/product_state.dart';

Future<void> main() async {
  const initial = ProductState();
  if (initial.isGetting || initial.isGettingList) {
    throw StateError('behavior check failed: initial state is loading');
  }
  if (initial.product != null || initial.productList.isNotEmpty) {
    throw StateError('behavior check failed: initial state carries data');
  }
  if (initial.isLoading || initial.hasError) {
    throw StateError('behavior check failed: derived getters wrong on '
        'initial state');
  }

  final loading = initial.copyWith(isGetting: true);
  if (!loading.isGetting || !loading.isLoading) {
    throw StateError('behavior check failed: isGetting transition lost');
  }

  final loaded = loading.copyWith(
    isGetting: false,
    product: Product(
      id: 'p1',
      name: 'Desk',
      price: 12.5,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
  if (loaded.product?.id != 'p1') {
    throw StateError('behavior check failed: entity transition lost');
  }
  if (loaded.productList.isNotEmpty) {
    throw StateError('behavior check failed: list leaked into entity '
        'transition');
  }
}
''');
        final run = await runBehaviorScript(fixture, script.path);
        expect(
          run.exitCode,
          0,
          reason:
              'generated state must EXECUTE (behavioral tier):\n'
              '${run.stdout}\n${run.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('diff guard', () {
    test(
      'regeneration with identical inputs is byte-stable (receipt)',
      () async {
        await expectByteStable(
          template: 'state',
          generate: (root) async {
            final files =
                await StatePlugin(
                  outputDir: p.join(root.path, 'lib', 'src'),
                  options: kSelfHostOptions,
                ).generate(
                  GeneratorConfig(
                    name: kFixtureEntityName,
                    methods: const ['get', 'getList'],
                    generateState: true,
                    outputDir: p.join(root.path, 'lib', 'src'),
                  ),
                );
            return files
                .map((f) => (path: f.path, content: f.content))
                .toList();
          },
        );
      },
    );
  });
}
