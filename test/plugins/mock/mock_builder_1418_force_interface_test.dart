// Issue #1418: `zfa mock create --force` must regenerate the WHOLE
// generated pair — the datasource interface AND the mock. The old guard
// was create-if-absent: a `--methods` change under `--force` regenerated
// the mock body from the current selection but left the interface
// declaring the STALE member set — the pair drifted and `--certify`
// dead-ended on `Missing concrete implementation of '<Entity>DataSource.<old>'`.
//
// The sequence below is the issue's exact reproduction, driven through
// MockPlugin (the same lane `mock create` dispatches to):
//   run 1: methods=[list]      → interface declares list(NoParams)
//   run 2: methods=[getList] + force → interface must declare
//          getList(ListQueryParams<Deal>) and NOT list(NoParams)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/mock/services/mock_staleness_detector.dart';

const _entitySource = '''
class Deal {
  final String id;
  final String title;
  const Deal({required this.id, required this.title});
}

class DealPatch {
  final String? id;
  final String? title;
  const DealPatch({this.id, this.title});
}
''';

void main() {
  late Directory workspace;
  late String outputDir;
  late FileSystem fs;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_issue_1418_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(
      p.join(outputDir, 'domain', 'entities', 'deal'),
    ).create(recursive: true);
    await File(
      p.join(outputDir, 'domain', 'entities', 'deal', 'deal.dart'),
    ).writeAsString(_entitySource);
    fs = FileSystem.create(root: workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  PluginContext context({
    required List<String> methods,
    bool force = false,
    bool append = false,
    bool revert = false,
  }) {
    return PluginContext(
      core: CoreConfig(
        name: 'Deal',
        projectRoot: workspace.path,
        outputDir: outputDir,
        force: force,
        revert: revert,
      ),
      data: <String, dynamic>{
        'mock': true,
        'data': true,
        'methods': methods,
        'id-field': 'id',
        'id-field-type': 'String',
        'query-field': 'id',
        if (append) 'append': true,
      },
      discovery: DiscoveryEngine(projectRoot: workspace.path, fileSystem: fs),
      fileSystem: fs,
    );
  }

  Future<MockPlugin> plugin({bool force = false}) async => MockPlugin(
    outputDir: outputDir,
    options: GeneratorOptions(force: force),
    fileSystem: fs,
  );

  String interfacePath() => p.join(
    outputDir,
    'data',
    'datasources',
    'deal',
    'deal_datasource.dart',
  );

  String mockPath() => p.join(
    outputDir,
    'data',
    'datasources',
    'deal',
    'deal_mock_datasource.dart',
  );

  /// Run 1 of the reproduction: a fresh certified pair for `list`.
  Future<void> seedListPair() async {
    await (await plugin(force: true)).generateWithContext(
      context(methods: const ['list'], force: true),
    );
    expect(File(interfacePath()).existsSync(), isTrue,
        reason: 'precondition: run 1 writes the interface');
    expect(File(mockPath()).existsSync(), isTrue,
        reason: 'precondition: run 1 writes the mock');
    final interface = File(interfacePath()).readAsStringSync();
    expect(interface, contains('list(NoParams'),
        reason: 'precondition: run 1 interface declares list(NoParams)');
  }

  test('T1: --force with a changed --methods regenerates the interface '
      'together with the mock', () async {
    await seedListPair();

    // Run 2 — the issue's failing command: --methods getList --force.
    final files = await (await plugin(force: true)).generateWithContext(
      context(methods: const ['getList'], force: true),
    );

    final interface = File(interfacePath()).readAsStringSync();
    expect(
      interface,
      contains('getList(ListQueryParams<Deal>'),
      reason:
          '#1418: --force must regenerate the interface from the CURRENT '
          '--methods selection — the stale list(NoParams) member is what '
          'dead-ends certification (out:\n$interface)',
    );
    expect(
      interface,
      isNot(contains('list(NoParams')),
      reason:
          '#1418: the stale member from run 1 must be gone — a stale '
          'interface member with a regenerated mock is the drift that '
          'fails the analyze gate (out:\n$interface)',
    );

    final mock = File(mockPath()).readAsStringSync();
    expect(mock, contains('getList(ListQueryParams<Deal>'),
        reason: 'the mock always regenerated from the current --methods');

    // The run reports the interface among its outputs (overwritten).
    expect(
      files.any((f) => f.path.endsWith('deal_datasource.dart')),
      isTrue,
      reason: 'the regenerated pair includes the interface file',
    );
  });

  test('T2: non-force run leaves an existing interface byte-identical '
      '(create-if-absent preserved)', () async {
    await seedListPair();
    final before = File(interfacePath()).readAsStringSync();

    await (await plugin()).generateWithContext(
      context(methods: const ['getList']),
    );

    final after = File(interfacePath()).readAsStringSync();
    expect(
      after,
      before,
      reason:
          'the non-force path keeps the #417 create-if-absent contract: '
          'without --force the interface is never rewritten from the mock '
          'lane',
    );
  });

  test('T3: --append (+force) does not regenerate the interface '
      '(append keeps its own contract)', () async {
    await seedListPair();
    final before = File(interfacePath()).readAsStringSync();

    await (await plugin(force: true)).generateWithContext(
      context(methods: const ['getList'], force: true, append: true),
    );

    final after = File(interfacePath()).readAsStringSync();
    expect(
      after,
      before,
      reason:
          'append mode never rewrites the interface from the mock lane — '
          'the same precedence the #1570 staleness arming applies to '
          'append runs',
    );
  });

  test('T4: --force on an absent interface still creates it '
      '(the #417 emission path survives)', () async {
    final files = await (await plugin(force: true)).generateWithContext(
      context(methods: const ['getList'], force: true),
    );

    expect(File(interfacePath()).existsSync(), isTrue);
    expect(File(mockPath()).existsSync(), isTrue);
    expect(
      files.any((f) => f.path.endsWith('deal_datasource.dart')),
      isTrue,
      reason: '#417: the interface is reported among the generated files',
    );
    final interface = File(interfacePath()).readAsStringSync();
    expect(interface, contains('getList(ListQueryParams<Deal>'));
  });

  test('T5: the --force-regenerated pair is structurally conforming '
      '(no missing members either direction)', () async {
    await seedListPair();

    await (await plugin(force: true)).generateWithContext(
      context(methods: const ['getList'], force: true),
    );

    // The certification's structural primitive: the same comparison the
    // --certify gate runs. Both directions must be clean — the mock
    // missing interface members (the issue's failure) AND invented
    // members the interface never declared.
    final missing = await MockStalenessDetector.detectMockStaleness(
      interfacePath: interfacePath(),
      interfaceClass: 'DealDataSource',
      mockPath: mockPath(),
      mockClass: 'DealMockDataSource',
      fileSystem: fs,
    );
    expect(
      missing,
      isEmpty,
      reason:
          '#1418: after the force regen the pair must be conforming — a '
          'missing member here is exactly the "unsatisfied: list" '
          'certification dead-end',
    );
  });
}
