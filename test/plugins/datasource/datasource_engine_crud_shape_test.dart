// Spec 1117 (issue #1117) — DataSource generator, engine trust tier:
// per-variant CRUD shape bar.
//
// The engine preset's datasource chain emits the interface plus the
// remote implementation by default (generateRemote defaults true), the
// local implementation for the synced lane (local-first), and appends
// methods to an existing pair for the append lane. This suite pins each
// lane's generated CRUD shape against the engine preset's default
// method set, reading the generated files from disk.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

/// The engine preset's default method set (spec 1002 / make_command).
const List<String> engineMethods = [
  'get',
  'getList',
  'create',
  'update',
  'delete',
];

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_ds_shape_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  DataSourcePlugin plugin() => DataSourcePlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  group('simple lane (engine default: interface + remote)', () {
    test('generates the right CRUD shape: the engine method set on the '
        'interface with a stub remote implementation', () async {
      final files = await plugin().generate(
        GeneratorConfig(
          name: 'Login',
          domain: 'auth',
          methods: engineMethods,
          generateDataSource: true,
          outputDir: outputDir,
        ),
      );

      // The simple lane emits the interface + the remote impl.
      expect(
        files.where((f) => f.type == 'datasource'),
        hasLength(1),
        reason: 'exactly one datasource interface',
      );
      expect(
        files.where((f) => f.type == 'remote_datasource'),
        hasLength(1),
        reason: 'the remote implementation (generateRemote defaults true)',
      );
      expect(
        files.where((f) => f.type == 'local_datasource'),
        isEmpty,
        reason: 'no local datasource in the simple lane',
      );

      final iface = _read(
        outputDir,
        'data/datasources/login/login_datasource.dart',
      );
      expect(
        iface,
        contains('abstract class LoginDataSource'),
        reason: 'the interface class name must match the entity',
      );
      // The full engine CRUD contract.
      expect(iface, contains('Future<Login> get(QueryParams<Login> params);'));
      expect(
        iface,
        contains('Future<List<Login>> getList(ListQueryParams<Login> params);'),
      );
      expect(iface, contains('Future<Login> create(Login login);'));
      expect(
        iface,
        contains(
          'Future<Login> update(UpdateParams<String, LoginPatch> params);',
        ),
        reason: 'the update member must carry the patch params shape',
      );
      expect(
        iface,
        contains('Future<void> delete(DeleteParams<String> params);'),
      );

      final remote = _read(
        outputDir,
        'data/datasources/login/login_remote_datasource.dart',
      );
      expect(
        remote,
        contains(
          'class LoginRemoteDataSource\n'
          '    with Loggable, FailureHandler\n'
          '    implements LoginDataSource {',
        ),
        reason: 'the remote impl must implement the interface',
      );
      // The stub bodies: every engine method throws the implementation
      // TODO marker.
      for (final member in engineMethods) {
        expect(
          remote,
          contains("throw UnimplementedError('Implement remote $member');"),
          reason: 'the $member stub body must name the member',
        );
      }
    });
  });

  group('synced lane (local + remote + interface)', () {
    test('generates the right CRUD shape: local-first lane emits the '
        'local implementation alongside interface and remote', () async {
      final files = await plugin().generate(
        GeneratorConfig(
          name: 'SyncEntity',
          domain: 'auth',
          methods: engineMethods,
          enableSync: true,
          generateDataSource: true,
          outputDir: outputDir,
        ),
      );

      // The synced lane adds the local implementation.
      expect(
        files.where((f) => f.type == 'local_datasource'),
        hasLength(1),
        reason: 'enableSync must emit the local datasource',
      );
      expect(
        files.where((f) => f.type == 'remote_datasource'),
        hasLength(1),
        reason: 'enableSync must also emit the remote datasource',
      );

      final local = _read(
        outputDir,
        'data/datasources/sync_entity/sync_entity_local_datasource.dart',
      );
      expect(
        local,
        contains('class SyncEntityLocalDataSource'),
        reason: 'the local class must be named after the entity',
      );
      // The local CRUD surface: the engine members with logging stubs
      // (the sync repository delegates reads/writes here).
      expect(
        local,
        contains('Future<SyncEntity> get(QueryParams<SyncEntity> params)'),
        reason: 'the local get member must exist for local-first reads',
      );
      expect(
        local,
        contains('Future<SyncEntity> create(SyncEntity syncEntity)'),
        reason: 'the local create member must exist for local-first writes',
      );

      final iface = _read(
        outputDir,
        'data/datasources/sync_entity/sync_entity_datasource.dart',
      );
      expect(
        iface,
        contains('Future<SyncEntity> update('),
        reason: 'the synced interface keeps the engine update member',
      );
    });
  });

  group('append lane (method appended to an existing pair)', () {
    test('generates the right CRUD shape: appended engine methods land on '
        'the existing interface + remote implementation', () async {
      // Phase 1 — baseline pair with a reduced method set.
      await plugin().generate(
        GeneratorConfig(
          name: 'Login',
          domain: 'auth',
          methods: const ['get', 'create'],
          generateDataSource: true,
          outputDir: outputDir,
        ),
      );

      // Phase 2 — append the remaining engine methods.
      await plugin().generate(
        GeneratorConfig(
          name: 'Login',
          domain: 'auth',
          methods: const ['update', 'delete'],
          appendToExisting: true,
          outputDir: outputDir,
        ),
      );

      final iface = _read(
        outputDir,
        'data/datasources/login/login_datasource.dart',
      );
      // Baseline members survive…
      expect(iface, contains('Future<Login> get(QueryParams<Login> params);'));
      // …and the appended engine members land alongside them.
      expect(
        iface,
        contains(
          'Future<Login> update(UpdateParams<String, LoginPatch> params);',
        ),
        reason: 'the appended update member must land on the interface',
      );
      expect(
        iface,
        contains('Future<void> delete(DeleteParams<String> params);'),
        reason: 'the appended delete member must land on the interface',
      );

      final remote = _read(
        outputDir,
        'data/datasources/login/login_remote_datasource.dart',
      );
      expect(
        remote,
        contains("throw UnimplementedError('Implement remote update');"),
        reason: 'the appended update stub must land on the remote impl',
      );
      expect(
        remote,
        contains("throw UnimplementedError('Implement remote delete');"),
        reason: 'the appended delete stub must land on the remote impl',
      );
    });
  });
}

String _read(String outputDir, String relativePath) =>
    File(p.join(outputDir, relativePath)).readAsStringSync();
