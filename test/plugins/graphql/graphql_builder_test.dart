// Issue #1149 (kill list, part of EPIC #1132 Machine Contract):
// `gql` was a near-byte-level duplicate of `graphql` — but it carried the
// CORRECT getList operation naming and FileSystem injection while graphql
// did not. This suite pins the folded-in fixes on the surviving
// GraphqlBuilder/GraphqlPlugin and the one-cycle `gql` → `graphql` alias.
//
// RED (pre-fix): `zfa make Product --methods=getList --with=graphql`
// emitted `usecase CreateProduct` — the getList case fell through to
// `create` AND the usecase plugin's `type` schema default (`usecase`)
// leaked into the GraphQL operation type.
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/core/planning/plan_resolver.dart';
import 'package:zuraffa/src/core/planning/plugin_alias_resolver.dart';
import 'package:zuraffa/src/config/zfa_config.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/graphql/builders/graphql_builder.dart';

/// In-memory [FileSystem] capturing writes — proves the builder persists
/// through the injected filesystem instead of hard-coding I/O.
class _CapturingFileSystem implements FileSystem {
  final Map<String, String> written = {};

  @override
  Future<String> read(String path) async => written[path] ?? '';

  @override
  String readSync(String path) => written[path] ?? '';

  @override
  Future<void> write(String path, String content) async {
    written[path] = content;
  }

  @override
  Future<void> delete(String path) async {
    written.remove(path);
  }

  @override
  Future<bool> exists(String path) async => written.containsKey(path);

  @override
  bool existsSync(String path) => written.containsKey(path);

  @override
  Future<void> createDir(String path, {bool recursive = false}) async {}

  @override
  Future<bool> isDirectory(String path) async => false;

  @override
  bool isDirectorySync(String path) => false;

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async =>
      const [];

  @override
  List<String> listSync(String path, {bool recursive = false}) => const [];

  @override
  Stream<String> watch(String path) => const Stream.empty();
}

GeneratorConfig _entityConfig({List<String>? methods}) => GeneratorConfig(
      name: 'Product',
      outputDir: '/tmp/graphql_test',
      generateGql: true,
      methods: methods ?? ['getList'],
    );

void main() {
  group('GraphqlBuilder operation naming (issue #1149 fold-in)', () {
    test('getList emits a query named Get<Entity>List (not Create<Entity>)',
        () async {
      final builder = GraphqlBuilder(outputDir: '/tmp/graphql_test');
      final files = await builder.generate(_entityConfig());

      expect(files, hasLength(1));
      final content = files.first.content!;
      expect(
        content,
        contains('query GetProductList'),
        reason:
            'getList must produce the Get<Entity>List operation. The '
            'pre-fold fallthrough emitted `CreateProduct`.',
      );
      expect(
        files.first.path,
        contains('get_product_list_query.dart'),
      );
    });

    test('every CRUD method keeps its canonical operation name', () async {
      final expected = <String, String>{
        'get': 'GetProduct',
        'getList': 'GetProductList',
        'create': 'CreateProduct',
        'update': 'UpdateProduct',
        'delete': 'DeleteProduct',
        'watch': 'WatchProduct',
        'watchList': 'WatchProductList',
      };
      final builder = GraphqlBuilder(outputDir: '/tmp/graphql_test');
      final files = await builder
          .generate(_entityConfig(methods: expected.keys.toList()));

      expect(files, hasLength(expected.length));
      final all = files.map((f) => f.content ?? '').join('\n');
      for (final entry in expected.entries) {
        expect(all, contains(entry.value),
            reason: '${entry.key} must name its operation ${entry.value}');
      }
    });
  });

  group('GraphqlBuilder FileSystem injection (issue #1149 fold-in)', () {
    test('writes through the injected FileSystem', () async {
      final fs = _CapturingFileSystem();
      final builder = GraphqlBuilder(
        outputDir: '/tmp/graphql_test',
        fileSystem: fs,
      );
      final files = await builder.generate(_entityConfig());

      expect(files, hasLength(1));
      expect(
        fs.written.keys,
        isNotEmpty,
        reason:
            'The builder must persist via the injected FileSystem — the '
            'graphql builder historically lacked the injection gql had.',
      );
      expect(fs.written[files.first.path], contains('GetProductList'));
    });
  });

  group('gql → graphql deprecation alias (issue #1149, one cycle)', () {
    test('PluginAliasResolver expands gql to graphql', () {
      final expanded = PluginAliasResolver.expandAll(['gql']);
      expect(expanded, ['graphql']);
    });

    test('PlanResolver activates GraphqlPlugin for --with=gql', () {
      final loader = PluginLoader(
        outputDir: 'lib/src',
        dryRun: false,
        force: false,
        verbose: false,
        config: PluginConfig(),
      );
      final registry = loader.buildRegistry();
      final resolver = PlanResolver(
        registry: registry,
        config: null,
        pluginConfig: null,
      );
      final plan = resolver.resolve(
        name: 'Product',
        options: const {
          'with': ['gql'],
        },
      );
      expect(
        plan.activePlugins.map((p) => p.id),
        contains('graphql'),
      );
      expect(
        plan.warnings.where((w) => w.contains('"gql"')),
        isEmpty,
        reason:
            'The aliased id must not surface as an unknown-plugin warning '
            'during the deprecation cycle.',
      );
    });

    test(
        "ZfaConfig.isPluginEnabledByDefault('graphql') honors the legacy gql key",
        () {
      final config = ZfaConfig(pluginDefaults: {'gql': true});
      expect(config.isPluginEnabledByDefault('graphql'), isTrue);
    });
  });
}
