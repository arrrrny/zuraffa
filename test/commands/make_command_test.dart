import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/cli/cli_runner.dart';
import '../helpers/project_root.dart';

void main() {
  group('MakeCommand', () {
    late Directory workspace;
    late String outputDir;
    late String previousCwd;
    late String zfaBin;
    late bool useCompiledBinary;

    Future<Process> startZfa(
      List<String> args, {
      required String workingDirectory,
    }) {
      if (useCompiledBinary) {
        return Process.start(zfaBin, args, workingDirectory: workingDirectory);
      }

      return Process.start('dart', [
        zfaBin,
        ...args,
      ], workingDirectory: workingDirectory);
    }

    setUpAll(() async {
      final homeDir = Platform.environment['HOME'] ?? '';
      final compiledBin = path.join(homeDir, '.local', 'bin', 'zfa');
      final compiledExists = File(compiledBin).existsSync();

      if (compiledExists) {
        zfaBin = compiledBin;
        useCompiledBinary = true;
      } else {
        // Resolve bin/zfa.dart relative to the project root, NOT CWD.
        // CWD may be a temp dir from another test at setUpAll time.
        final projectRoot = await findProjectRoot();
        zfaBin = path.join(projectRoot, 'bin', 'zfa.dart');
        useCompiledBinary = false;
      }
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_make_command_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_make_test
environment:
  sdk: ^3.11.0
''');
      final entityDir = Directory(
        path.join(outputDir, 'domain', 'entities', 'product'),
      );
      await entityDir.create(recursive: true);
      await File(path.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
      previousCwd = Directory.current.path;
      Directory.current = workspace.path;
    });

    tearDown(() async {
      // Always restore CWD to a known-valid directory before deleting
      // the workspace, to prevent poisoning CWD for subsequently loaded
      // test files that call findProjectRoot() at the top of main().
      try {
        if (Directory(previousCwd).existsSync()) {
          Directory.current = previousCwd;
        } else {
          Directory.current = Directory.systemTemp.path;
        }
      } catch (_) {
        try {
          Directory.current = Directory.systemTemp.path;
        } catch (_) {}
      }
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('supports --format=json with --plan', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'make',
        'Product',
        '--preset=crud',
        '--with=vpc',
        '--plan',
        '--format=json',
        '--output',
        outputDir,
      ]);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final plan = decoded['plan'] as Map<String, dynamic>;
      expect(
        (plan['plugin_ids'] as List).cast<String>(),
        containsAll([
          'usecase',
          'repository',
          'datasource',
          'view',
          'presenter',
          'controller',
        ]),
      );
    });

    test('fails fast when entity does not exist', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'make',
        'NonExistentEntity',
        '--preset=crud',
        '--plan',
        '--format=json',
        '--output',
        outputDir,
      ]);

      // #496: when the entity source file is missing (and --no-entity is not
      // set) `zfa make` must fail fast with an actionable error instead of
      // silently proceeding with a default `id` field. The output must NOT
      // report success or regenerate code.
      expect(
        output,
        contains('no entity source file'),
        reason: 'expected an entity-not-found diagnostic',
      );
      expect(output, contains('zfa entity create -n NonExistentEntity'));
      expect(
        output,
        isNot(contains('"success": true')),
        reason: 'must NOT report success for a missing entity',
      );
    });

    test('supports --from-json for plan resolution', () async {
      final configFile = File(path.join(workspace.path, 'make_config.json'));
      await configFile.writeAsString(
        jsonEncode({
          'name': 'Product',
          'preset': 'crud',
          'with': ['vpc'],
        }),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'make',
        '--from-json',
        configFile.path,
        '--plan',
        '--format=json',
        '--output',
        outputDir,
      ]);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final plan = decoded['plan'] as Map<String, dynamic>;
      expect(plan['preset'], 'crud');
      expect((plan['plugin_ids'] as List).cast<String>(), contains('usecase'));
    });

    test('supports explicit exclusions and negation over defaults', () async {
      await File(path.join(workspace.path, '.zfa.json')).writeAsString(
        jsonEncode({
          'plugins': {
            'defaults': {'di': true, 'route': true},
          },
        }),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing([
        'make',
        'Product',
        '--preset=crud',
        '--with=controller',
        '--without=route',
        '--no-controller',
        '--plan',
        '--format=json',
        '--output',
        outputDir,
      ]);

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final plan = decoded['plan'] as Map<String, dynamic>;
      final pluginIds = (plan['plugin_ids'] as List).cast<String>();
      expect(pluginIds, contains('di'));
      expect(pluginIds, isNot(contains('route')));
      expect(pluginIds, isNot(contains('controller')));
    });

    test(
      'supports --from-stdin for plan resolution',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final process = await startZfa([
          'make',
          '--from-stdin',
          '--plan',
          '--format=json',
          '--output',
          outputDir,
        ], workingDirectory: previousCwd);

        process.stdin.writeln(
          jsonEncode({
            'name': 'Product',
            'preset': 'crud',
            'with': ['vpc'],
          }),
        );
        await process.stdin.close();

        final stdoutOutput = await process.stdout
            .transform(utf8.decoder)
            .join();
        final stderrOutput = await process.stderr
            .transform(utf8.decoder)
            .join();
        final exitCode = await process.exitCode;

        expect(exitCode, equals(0), reason: stderrOutput);

        final jsonMatch = RegExp(
          r'\{.*"success".*\}',
          dotAll: true,
        ).firstMatch(stdoutOutput);
        expect(
          jsonMatch,
          isNotNull,
          reason: 'No JSON found in stdout: $stdoutOutput',
        );
        final decoded =
            jsonDecode(jsonMatch!.group(0)!) as Map<String, dynamic>;
        expect(decoded['success'], isTrue);
        final plan = decoded['plan'] as Map<String, dynamic>;
        expect(plan['preset'], 'crud');
        expect(
          (plan['plugin_ids'] as List).cast<String>(),
          contains('repository'),
        );
      },
    );
  });

  group('MakeCommand #307 identity contract', () {
    late Directory workspace;
    late String outputDir;
    late String zfaSourceBin;

    // Handle to the child `dart` process spawned by [runZfaSource], kept so
    // tearDown can guarantee it is terminated before the workspace is deleted.
    Process? zfaProcess;

    // Runs zfa from SOURCE (never the stale compiled ~/.local/bin/zfa) as a
    // subprocess with an explicit workingDirectory — no process-global
    // `Directory.current` mutation, so this group cannot race with other
    // test files that capture the cwd at load time (see #296 test).
    //
    // Uses [Process.start] (not [Process.run]) so we hold the child's
    // [Process] handle. If the test times out, the child may still be alive
    // and holding the workspace; tearDown kills it before cleanup. stdout/
    // stderr are collected concurrently with the exit code to avoid a
    // pipe-buffer deadlock (the caller sees the same [ProcessResult] shape
    // that [Process.run] would have produced).
    Future<ProcessResult> runZfaSource(List<String> args) async {
      final process = await Process.start('dart', [
        zfaSourceBin,
        ...args,
      ], workingDirectory: workspace.path);
      zfaProcess = process;

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      return ProcessResult(process.pid, exitCode, stdout, stderr);
    }

    setUpAll(() async {
      final projectRoot = await findProjectRoot();
      zfaSourceBin = path.join(projectRoot, 'bin', 'zfa.dart');
    });

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_make_identity_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_make_identity_test
environment:
  sdk: ^3.11.0
dependencies:
  uuid: ^4.6.0
''');
      zfaProcess = null;
    });

    tearDown(() async {
      // Terminate any still-running subprocess BEFORE deleting its workspace.
      // If the test timed out, the child `dart` process (and the files it is
      // still writing/removing) is alive; deleting the directory it holds
      // races and throws PathNotFoundException. Kill first, then reap.
      if (zfaProcess != null) {
        try {
          zfaProcess!.kill(ProcessSignal.sigkill);
        } catch (_) {
          // Already exited — ignore.
        }
        await zfaProcess!.exitCode
            .timeout(const Duration(seconds: 10))
            .catchError((_) => -1);
        zfaProcess = null;
      }
      if (workspace.existsSync()) {
        try {
          await workspace.delete(recursive: true);
        } on PathNotFoundException {
          // A late-exiting child may still be removing files concurrently;
          // tolerate ENOENT during recursive enumeration instead of failing
          // the teardown (issue #503).
        }
      }
    });

    Future<void> writeEntity(String name, String content) async {
      final snake = name.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => (m.start == 0 ? '' : '_') + m.group(0)!.toLowerCase(),
      );
      final dir = Directory(path.join(outputDir, 'domain', 'entities', snake));
      await dir.create(recursive: true);
      await File(path.join(dir.path, '$snake.dart')).writeAsString(content);
    }

    test(
      '#307 — an id-less entity fails loudly instead of falling back to its '
      'first (enum) field',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await writeEntity('ChatMessage', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@Zorphy(generateJson: true, generateCompareTo: true)
abstract class \$ChatMessage {
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}
''');

        final result = await runZfaSource([
          'make',
          'ChatMessage',
          '--preset=crud',
          '--with=vpc,state,di,test,mock',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, isNot(0));
        expect(
          result.stdout as String,
          contains('has no id field'),
          reason: 'stdout: ${result.stdout}',
        );
        // The enum-typed-id fallback must never happen.
        expect(result.stdout as String, isNot(contains('Resolved id field')));
      },
    );

    test(
      '#307 — autoId: true resolves the identity to a String id even without '
      'an id getter in the source',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await writeEntity('TelemetryEvent', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@Zorphy(generateJson: true, autoId: true)
abstract class \$TelemetryEvent {
  TelemetryEventType get type;
  String get value;
}
''');

        final result = await runZfaSource([
          'make',
          'TelemetryEvent',
          '--preset=crud',
          '--with=vpc',
          '--verbose',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        expect(
          result.stdout as String,
          contains('Resolved id field for "TelemetryEvent": id (String)'),
          reason: 'stdout: ${result.stdout}',
        );
      },
    );

    test(
      'value object — make skips the root plugins and does not generate '
      'repository/usecase/controller/presenter',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await writeEntity('ParserConfig', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@ZValueObject
abstract class \$ParserConfig {
  String get separator;
  bool get trimWhitespace;
}
''');

        final result = await runZfaSource([
          'make',
          'ParserConfig',
          '--preset=crud',
          '--with=vpc,state,di,test,mock',
          '--output',
          outputDir,
        ]);

        expect(result.exitCode, 0, reason: 'stderr: ${result.stderr}');
        final stdout = result.stdout as String;
        expect(stdout, contains('is a value object — skipping root plugins'));
        expect(stdout, contains('usecase'));
        expect(stdout, contains('presenter'));

        // No persisted/root surface is generated...
        final domainUsecases = Directory(
          path.join(outputDir, 'domain', 'usecases'),
        );
        expect(domainUsecases.existsSync(), isFalse);
        final domainRepos = Directory(
          path.join(outputDir, 'domain', 'repositories'),
        );
        expect(domainRepos.existsSync(), isFalse);
        // ...but embedded-type tooling (mock data) still runs.
        final dataDir = Directory(path.join(outputDir, 'data'));
        expect(
          dataDir.existsSync() &&
              dataDir
                  .listSync(recursive: true)
                  .any(
                    (f) =>
                        f.path.endsWith('parser_config_mock_data.dart') ||
                        f.path.endsWith('parser_config_mock_entity.dart'),
                  ),
          isTrue,
          reason: 'expected mock data under ${dataDir.path}',
        );
      },
    );

    // #346: `zfa make --with=di` must generate datasource DI registrations.
    // PluginManager.buildContext used to fill schema defaults (e.g.
    // RepositoryPlugin's `datasource: false`) BEFORE syncing plugin
    // activation flags, so `data['datasource']` was clobbered to false and
    // the DI plugin never emitted lib/src/di/datasources/ — the app compiled
    // but crashed at runtime with
    // `GetIt: ProductRemoteDataSource is not registered`.
    test(
      '#346 — with di generates and wires datasource DI registrations',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await writeEntity('Product', '''
class Product {
  final String id;

  const Product({required this.id});
}
''');

        final result = await runZfaSource([
          'make',
          'Product',
          '--preset=crud',
          '--with=di',
          '--methods=get,getList',
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());

        final diPath = path.join(outputDir, 'di');

        // 1. Datasource DI registration file exists and registers the
        //    datasource in GetIt.
        final dsDi = File(
          path.join(diPath, 'datasources', 'product_remote_datasource_di.dart'),
        );
        expect(dsDi.existsSync(), isTrue, reason: 'datasource DI file missing');
        final dsContent = dsDi.readAsStringSync();
        expect(dsContent, contains('void registerProductRemoteDataSource('));
        expect(
          dsContent,
          contains('getIt.registerLazySingleton<ProductRemoteDataSource>('),
        );

        // 2. Datasource barrel exists and is called by setupDependencies
        //    BEFORE repositories (repositories resolve datasources from GetIt).
        final dsIndex = File(path.join(diPath, 'datasources', 'index.dart'));
        expect(dsIndex.existsSync(), isTrue);
        expect(
          dsIndex.readAsStringSync(),
          contains('registerAllDataSources(GetIt getIt)'),
        );

        final mainContent = File(
          path.join(diPath, 'index.dart'),
        ).readAsStringSync();
        expect(mainContent, contains('registerAllDataSources(getIt);'));
        expect(
          mainContent.indexOf('registerAllDataSources(getIt);'),
          lessThan(mainContent.indexOf('registerAllRepositories(getIt);')),
          reason: 'datasources must be registered before repositories',
        );
      },
    );

    // #346 (mock variant): `--use-mock` must register the mock datasource
    // instead of the remote one.
    test(
      '#346 — with di --use-mock registers the mock datasource',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await writeEntity('Product', '''
class Product {
  final String id;

  const Product({required this.id});
}
''');

        final result = await runZfaSource([
          'make',
          'Product',
          '--preset=crud',
          '--with=di',
          '--use-mock',
          '--methods=get',
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());

        final mockDi = File(
          path.join(
            outputDir,
            'di',
            'datasources',
            'product_mock_datasource_di.dart',
          ),
        );
        expect(
          mockDi.existsSync(),
          isTrue,
          reason: 'mock datasource DI missing',
        );
        expect(
          mockDi.readAsStringSync(),
          contains('registerProductMockDataSource('),
        );

        final dsIndex = File(
          path.join(outputDir, 'di', 'datasources', 'index.dart'),
        );
        expect(
          dsIndex.readAsStringSync(),
          contains('registerProductMockDataSource(getIt);'),
        );
      },
    );

    // #412: `zfa make <Entity> repository usecase di mock provider service
    // datasource` used to crash with `type 'bool' is not a subtype of type
    // 'String?' in type cast` because the activation sync in
    // PluginManager.buildContext wrote `data['service'] = true` (bool) for
    // the active `service` plugin, poisoning the string-typed `service`
    // schema slot that ServicePlugin (and UseCasePlugin) declare. Every
    // consumer that read `data['service'] as String?` — or
    // `context.get<String>('service')` — then crashed at runtime, even
    // though individual `zfa <plugin> create <Entity>` invocations worked
    // (they don't go through MakeCommand's activation sync).
    //
    // The fix is two-pronged:
    //   1. PluginContext.get<T> is now defensive — returns null when the
    //      stored value isn't a T, instead of throwing a cast error.
    //   2. The activation sync records the activation flag under
    //      `data['__active_<id>']` (queried via `PluginContext.isActive`)
    //      for plugin ids whose own schema declares them as a non-boolean
    //      type, leaving `data[id]` for the typed value (String/int/...).
    //
    // This regression test exercises the FULL plugin bundle from the issue
    // (repository + usecase + di + mock + provider + service + datasource)
    // and asserts the make command exits 0 and emits the canonical
    // service + DI registrations. It uses TestEntity (matching the issue's
    // reproduction) so the field names in the generated code line up with
    // the issue's repro.
    test(
      '#412 — full plugin bundle (repository usecase di mock provider '
      'service datasource) does not crash with bool→String? cast',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        await writeEntity('TestEntity', '''
class TestEntity {
  final String id;
  final String name;

  const TestEntity({required this.id, required this.name});
}
''');

        final result = await runZfaSource([
          'make',
          'TestEntity',
          'repository',
          'usecase',
          'di',
          'mock',
          'provider',
          'service',
          'datasource',
        ]);

        // The crash used to happen mid-run (UseCasePlugin reading
        // `data['service']` as String?), so a non-zero exit code is the
        // primary regression signal. Stderr is the secondary signal — the
        // CLI runner's catch-all prints `❌ Error: ...` to stderr.
        expect(
          result.exitCode,
          0,
          reason:
              'zfa make full bundle crashed:\n'
              'stdout: ${result.stdout}\n'
              'stderr: ${result.stderr}',
        );
        expect(
          result.stderr.toString(),
          isNot(contains("type 'bool' is not a subtype of type 'String?'")),
        );
        expect(
          result.stdout.toString(),
          isNot(contains('❌ Generation failed')),
        );

        // The `service` plugin must have been treated as active — DI's
        // `generateService` flag is driven by `context.isActive('service')`
        // after the fix, so the canonical service DI registration should
        // land. Without the `isActive` helper, DI would have silently
        // skipped service registration (data['service'] was no longer the
        // bool `true` the old check expected).
        //
        // We assert on the per-barrel index files (datasources/repositories/
        // usecases) because they each reference the entity-keyed DI file
        // that was generated for that layer — proving the corresponding
        // plugin ran AND DI registered it. The top-level di/index.dart
        // only re-exports the per-barrel indexes, so it's not a useful
        // signal for "did plugin X run".
        final dsIndex = File(
          path.join(outputDir, 'di', 'datasources', 'index.dart'),
        );
        expect(
          dsIndex.existsSync(),
          isTrue,
          reason: 'di/datasources/index.dart missing — DI plugin did not run',
        );
        expect(
          dsIndex.readAsStringSync(),
          contains('test_entity_remote_datasource_di.dart'),
          reason:
              'DI did not register the datasource DI barrel — '
              'isActive("service") likely regressed',
        );

        final repoIndex = File(
          path.join(outputDir, 'di', 'repositories', 'index.dart'),
        );
        expect(
          repoIndex.readAsStringSync(),
          contains('test_entity_repository_di.dart'),
          reason: 'DI did not register the repository DI barrel',
        );

        final ucIndex = File(
          path.join(outputDir, 'di', 'usecases', 'index.dart'),
        );
        expect(
          ucIndex.readAsStringSync(),
          contains('get_test_entity_usecase_di.dart'),
          reason: 'DI did not register the usecase DI barrel',
        );
      },
    );
  });

  // #508: the #307 loud no-id failure over-applies — it runs before plugin
  // dispatch, so `zfa make <Entity> --test` (test = id-NEUTRAL: it only
  // regenerates test files from ALREADY-GENERATED usecases) was blocked for
  // entities that legitimately have no id. The loud failure must fire only
  // when an id-DEPENDENT plugin (repository/usecase/controller/presenter/
  // datasource/...) is active.
  //
  // These tests use the in-process `runCapturing` pattern (see the comment
  // at the MakeCommandException throw site): the zone's catch-all records
  // the diagnostic without killing the test isolate, so we can assert on
  // both the green path (no error) and the red path (the #307 message).
  group('MakeCommand #508 id-neutral regeneration', () {
    late Directory workspace;
    late String outputDir;
    late String previousCwd;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_make_508_');
      outputDir = path.join(workspace.path, 'lib', 'src');
      await Directory(outputDir).create(recursive: true);
      await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_make_508_test
environment:
  sdk: ^3.11.0
dependencies:
  uuid: ^4.6.0
''');
      previousCwd = Directory.current.path;
      Directory.current = workspace.path;
    });

    tearDown(() async {
      try {
        if (Directory(previousCwd).existsSync()) {
          Directory.current = previousCwd;
        } else {
          Directory.current = Directory.systemTemp.path;
        }
      } catch (_) {
        try {
          Directory.current = Directory.systemTemp.path;
        } catch (_) {}
      }
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    /// Id-less entity whose FIRST field is an enum (#307's worst case):
    /// the representative query field must skip `role` and pick the first
    /// real scalar (`content`: String), never `role`, never a synthetic id.
    Future<void> writeIdLessEntity() async {
      final dir = Directory(
        path.join(outputDir, 'domain', 'entities', 'chat_message'),
      );
      await dir.create(recursive: true);
      await File(path.join(dir.path, 'chat_message.dart')).writeAsString('''
import 'package:zorphy_annotation/zorphy_annotation.dart';

@Zorphy(generateJson: true, generateCompareTo: true)
abstract class \$ChatMessage {
  ChatMessageRole get role;
  String get content;
  DateTime get timestamp;
}
''');
    }

    /// Pre-existing usecase sources (the #508 premise: the usecases already
    /// exist; --test only regenerates their test files). The marker comment
    /// lets the red-path test prove no file was touched.
    Future<void> writeExistingUseCases() async {
      final dir = Directory(
        path.join(outputDir, 'domain', 'usecases', 'chat_message'),
      );
      await dir.create(recursive: true);
      for (final method in ['get', 'update', 'toggle']) {
        await File(
          path.join(dir.path, '${method}_chat_message_usecase.dart'),
        ).writeAsString('// FIXTURE-STUB $method\n');
      }
    }

    test(
      '#508 — --test only on an id-less entity succeeds and references a '
      'real field',
      () async {
        await writeIdLessEntity();
        await writeExistingUseCases();

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          'make',
          'ChatMessage',
          '--test',
          '--force',
          '--output',
          outputDir,
        ]);

        expect(
          output,
          isNot(contains('has no id field')),
          reason:
              '--test is id-neutral; the #307 loud failure must not fire '
              '(issue #508). Output:\n$output',
        );
        expect(output, isNot(contains('❌ Error')));

        final getTest = File(
          path.join(
            workspace.path,
            'test',
            'domain',
            'usecases',
            'chat_message',
            'get_chat_message_usecase_test.dart',
          ),
        );
        expect(
          getTest.existsSync(),
          isTrue,
          reason: 'the get usecase test must be regenerated\noutput:\n$output',
        );
        final content = getTest.readAsStringSync();
        expect(
          content,
          contains('ChatMessageFields.content'),
          reason: 'the query/filter key must be the representative REAL '
              'field (first String), not a synthetic id',
        );
        expect(content, isNot(contains('ChatMessageFields.id')));
        expect(
          content,
          isNot(contains('ChatMessageFields.role')),
          reason: 'an enum-typed field must never be the query field (#307)',
        );
      },
    );

    test(
      '#508 — explicit --query-field is preserved on the id-neutral path',
      () async {
        await writeIdLessEntity();
        await writeExistingUseCases();

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          'make',
          'ChatMessage',
          '--test',
          '--force',
          '--query-field',
          'timestamp',
          '--output',
          outputDir,
        ]);

        expect(output, isNot(contains('has no id field')));
        final getTest = File(
          path.join(
            workspace.path,
            'test',
            'domain',
            'usecases',
            'chat_message',
            'get_chat_message_usecase_test.dart',
          ),
        );
        expect(getTest.existsSync(), isTrue, reason: 'output:\n$output');
        final content = getTest.readAsStringSync();
        expect(
          content,
          contains('ChatMessageFields.timestamp'),
          reason: 'the user-provided query field must win over auto-resolution',
        );
        expect(content, isNot(contains('ChatMessageFields.content')));
      },
    );

    test(
      '#508/#307 — an id-dependent plugin on an id-less entity still fails '
      'loudly',
      () async {
        await writeIdLessEntity();
        await writeExistingUseCases();

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          'make',
          'ChatMessage',
          'usecase',
          '--force',
          '--output',
          outputDir,
        ]);

        // Same #307 diagnostic: message + the three remediation hints.
        expect(output, contains('has no id field'));
        expect(output, contains('--auto-id'));
        expect(output, contains('value_object'));
        expect(output, contains('add-field'));
        expect(output, contains('❌ Error: Cannot generate architecture'));

        // The failure precedes plugin dispatch: no test files regenerated,
        // and the pre-existing usecase stubs are untouched.
        final testDir = Directory(
          path.join(workspace.path, 'test', 'domain', 'usecases'),
        );
        expect(testDir.existsSync(), isFalse);
        final stub = File(
          path.join(
            outputDir,
            'domain',
            'usecases',
            'chat_message',
            'get_chat_message_usecase.dart',
          ),
        );
        expect(stub.readAsStringSync(), contains('// FIXTURE-STUB get'));
      },
    );

    test(
      '#508/#307 — a mixed request (--test plus an id-dependent plugin via '
      '--methods) still fails loudly',
      () async {
        await writeIdLessEntity();
        await writeExistingUseCases();

        // --methods implies the usecase plugin (PlanResolver's
        // _hasEntityMethods), so the active set is {usecase, test} — the
        // id-dependent member must keep the loud failure armed.
        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          'make',
          'ChatMessage',
          '--test',
          '--methods=get',
          '--force',
          '--output',
          outputDir,
        ]);

        expect(output, contains('has no id field'));
        expect(output, contains('❌ Error: Cannot generate architecture'));
      },
    );

    // #514: in apps/zikzak_demo `usecase` is enabled by default in .zfa.json.
    // `zfa make <NoId> --test` then resolves to {usecase, test} and the #307
    // gate fired even though the user only wanted id-neutral test
    // regeneration. The fix drops the implied (config-default) usecase so the
    // id-neutral path proceeds.
    test(
      '#514 — no-id entity with usecase default-enabled: --test regenerates '
      'id-neutrally (drops the implied usecase)',
      () async {
        await File(path.join(workspace.path, '.zfa.json')).writeAsString(
          jsonEncode({
            'plugins': {
              'defaults': {'usecase': true},
            },
          }),
        );
        await writeIdLessEntity();
        await writeExistingUseCases();

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          'make',
          'ChatMessage',
          '--test',
          '--force',
          '--output',
          outputDir,
        ]);

        // The implied usecase is dropped (notice printed) and no loud failure
        // fires — note the drop notice itself contains the words "has no id
        // field", so we assert on the error path, not the phrase.
        expect(
          output,
          contains('dropping id-dependent plugins implied by config defaults'),
          reason: 'the config-default usecase must be dropped (issue #514)',
        );
        expect(output, isNot(contains('❌ Error')));
        expect(
          output,
          isNot(contains('Cannot generate architecture')),
          reason: 'id-neutral regeneration must proceed, not fail',
        );

        final getTest = File(
          path.join(
            workspace.path,
            'test',
            'domain',
            'usecases',
            'chat_message',
            'get_chat_message_usecase_test.dart',
          ),
        );
        expect(getTest.existsSync(), isTrue, reason: 'output:\n$output');
        final content = getTest.readAsStringSync();
        expect(
          content,
          contains('ChatMessageFields.content'),
          reason: 'the query key must be the representative REAL field',
        );
        expect(content, isNot(contains('ChatMessageFields.id')));

        // The implied usecase plugin must NOT have run — the pre-existing
        // usecase stub is untouched.
        final stub = File(
          path.join(
            outputDir,
            'domain',
            'usecases',
            'chat_message',
            'get_chat_message_usecase.dart',
          ),
        );
        expect(
          stub.readAsStringSync(),
          contains('// FIXTURE-STUB get'),
          reason: 'the dropped usecase plugin should not regenerate usecases',
        );
      },
    );

    // Complement: without an id-neutral flag the implied (config-default)
    // usecase must keep the #307 loud failure armed.
    test(
      '#514 — bare make (no --test/--mock) on a no-id entity with usecase '
      'default still fails loudly',
      () async {
        await File(path.join(workspace.path, '.zfa.json')).writeAsString(
          jsonEncode({
            'plugins': {
              'defaults': {'usecase': true},
            },
          }),
        );
        await writeIdLessEntity();
        await writeExistingUseCases();

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing([
          'make',
          'ChatMessage',
          '--force',
          '--output',
          outputDir,
        ]);

        expect(
          output,
          contains('has no id field'),
          reason: 'without --test/--mock the implied usecase must keep the '
              'loud failure armed',
        );
        expect(output, contains('❌ Error: Cannot generate architecture'));
      },
    );
  });
}
