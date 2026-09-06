// Spec 1117 (issue #1117) — Repository generator, engine trust tier:
// per-variant CRUD shape bar.
//
// The engine preset's repository chain emits one of three impl variants
// — simple (single datasource), synced (local-first + sync surface),
// append (custom-usecase method added to an existing pair). This suite
// pins each variant's generated CRUD shape against the engine preset's
// default method set (get/getList/create/update/delete), reading the
// generated files from disk exactly as the engine receipt does.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

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
    tempDir = await Directory.systemTemp.createTemp('zfa_repo_shape_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  RepositoryPlugin plugin() => RepositoryPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: true),
  );

  group('simple variant (engine default)', () {
    test('generates the right CRUD shape: full engine method set '
        'delegating to the single datasource', () async {
      final files = await plugin().generate(
        GeneratorConfig(
          name: 'Login',
          domain: 'auth',
          methods: engineMethods,
          generateDataSource: true,
          outputDir: outputDir,
        ),
      );

      // The pair: interface + data implementation (+ datasource
      // interface the impl imports — the repository plugin emits it when
      // the datasource plugin is not active).
      expect(
        files.where((f) => f.type == 'repository').map((f) => f.path),
        contains(
          p.join(outputDir, 'domain', 'repositories', 'login_repository.dart'),
        ),
        reason: 'the interface must land at the canonical path',
      );
      expect(
        files.where((f) => f.type == 'repository_implementation'),
        hasLength(1),
        reason: 'exactly one data implementation',
      );

      final iface = _read(
        outputDir,
        'domain/repositories/login_repository.dart',
      );
      // The engine preset's five CRUD members with the framework param
      // family (update carries the zorphy patch shape).
      expect(
        iface,
        contains('Future<Login> get(QueryParams<Login> params);'),
        reason: 'get member must use QueryParams',
      );
      expect(
        iface,
        contains('Future<List<Login>> getList(ListQueryParams<Login> params);'),
        reason: 'getList member must use ListQueryParams',
      );
      expect(
        iface,
        contains('Future<Login> create(Login login);'),
        reason: 'create member takes the entity',
      );
      expect(
        iface,
        contains(
          'Future<Login> update(UpdateParams<String, LoginPatch> params);',
        ),
        reason: 'update member must use the patch params shape',
      );
      expect(
        iface,
        contains('Future<void> delete(DeleteParams<String> params);'),
        reason: 'delete member must use DeleteParams',
      );

      final impl = _read(
        outputDir,
        'data/repositories/data_login_repository.dart',
      );
      // The CRUD delegation: every member forwards to _dataSource.
      expect(
        impl,
        contains(
          'class DataLoginRepository\n'
          '    with Loggable, FailureHandler\n'
          '    implements LoginRepository {',
        ),
        reason:
            'the impl must implement the interface with the '
            'framework mixins',
      );
      expect(impl, contains('DataLoginRepository(this._dataSource);'));
      expect(impl, contains('final LoginDataSource _dataSource;'));
      for (final member in engineMethods) {
        expect(
          impl,
          contains('_dataSource.$member('),
          reason: 'the $member member must delegate to the datasource',
        );
      }
      // The datasource pair the impl imports.
      expect(
        _read(outputDir, 'data/datasources/login/login_datasource.dart'),
        contains('abstract class LoginDataSource'),
        reason: 'the datasource interface the impl imports must exist',
      );
    });
  });

  group('synced variant', () {
    test(
      'generates the right CRUD shape: local-first writes with the '
      'sync surface (markPending/markDeleted, syncPending/pullRemote)',
      () async {
        await plugin().generate(
          GeneratorConfig(
            name: 'SyncEntity',
            domain: 'auth',
            methods: engineMethods,
            enableSync: true,
            generateDataSource: true,
            outputDir: outputDir,
          ),
        );

        final iface = _read(
          outputDir,
          'domain/repositories/sync_entity_repository.dart',
        );
        // The sync surface lives on the interface contract.
        expect(
          iface,
          contains('Future<void> syncPending({CancelToken? cancelToken});'),
          reason: 'the interface must expose syncPending',
        );
        expect(
          iface,
          contains('Future<void> pullRemote({CancelToken? cancelToken});'),
          reason: 'the interface must expose pullRemote',
        );

        final impl = _read(
          outputDir,
          'data/repositories/data_sync_entity_repository.dart',
        );
        // Local-first constructor: local + remote datasources, the
        // metadata store, and the sync strategy.
        expect(
          impl,
          contains('DataSyncEntityRepository('),
          reason: 'the synced impl takes the four sync dependencies',
        );
        expect(
          impl,
          contains('final SyncEntityLocalDataSource _localDataSource;'),
        );
        expect(impl, contains('final SyncMetadataStore _syncMetadataStore;'));
        expect(impl, contains('final SyncStrategy<SyncEntity> _syncStrategy;'));
        // Reads go local-first.
        expect(
          impl,
          contains('return await _localDataSource.get(params);'),
          reason: 'reads must be local-first in the synced variant',
        );
        // Writes mark the sync ledger.
        expect(
          impl,
          contains(
            'await _syncStrategy.markPending<SyncOperation.create>(saved.id);',
          ),
          reason: 'create must mark the entity pending sync',
        );
        expect(
          impl,
          contains('_syncStrategy.markDeleted(params.id.toString());'),
          reason: 'delete must mark the entity deleted for sync',
        );
        // The sync surface delegates to the strategy.
        expect(
          impl,
          contains(
            'await _syncStrategy.syncPending(cancelToken: cancelToken);',
          ),
          reason: 'syncPending must delegate to the strategy',
        );
      },
    );
  });

  group('append variant (custom usecase)', () {
    test('generates the right CRUD shape: the login method is appended '
        'to BOTH the existing interface and the data implementation', () async {
      // Phase 1 — the baseline pair the engine preset would have
      // generated earlier in the cycle.
      await plugin().generate(
        GeneratorConfig(
          name: 'Login',
          domain: 'auth',
          methods: const ['get', 'create'],
          generateDataSource: true,
          outputDir: outputDir,
        ),
      );

      // Phase 2 — the pilot's append: a custom login usecase appends its
      // method to the existing repository pair.
      final files = await plugin().generate(
        GeneratorConfig(
          name: 'Login',
          domain: 'auth',
          repo: 'Login',
          repoMethod: 'login',
          appendToExisting: true,
          outputDir: outputDir,
        ),
      );

      // The append updates (not recreates) both sides.
      expect(
        files.where((f) => f.action == 'updated').map((f) => f.type),
        containsAll(const ['repository', 'repository_implementation']),
        reason: 'the append must update the interface and the impl',
      );

      final iface = _read(
        outputDir,
        'domain/repositories/login_repository.dart',
      );
      expect(
        iface,
        contains('Future<Login> get(QueryParams<Login> params);'),
        reason: 'the baseline members must survive the append',
      );
      expect(
        iface,
        contains('Future<void> login(NoParams params);'),
        reason:
            'the appended member must land on the interface with the '
            'NoParams shape a custom usecase passes',
      );

      final impl = _read(
        outputDir,
        'data/repositories/data_login_repository.dart',
      );
      expect(
        impl,
        contains('Future<void> login(NoParams params) {'),
        reason: 'the appended member must land on the impl',
      );
      expect(
        impl,
        contains('return _dataSource.login(params);'),
        reason: 'the appended member must delegate to the datasource',
      );
    });
  });
}

String _read(String outputDir, String relativePath) =>
    File(p.join(outputDir, relativePath)).readAsStringSync();
