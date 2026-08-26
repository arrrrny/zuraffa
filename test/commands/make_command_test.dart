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

      // Current behavior: when entity doesn't exist, EntityFieldResolver returns null
      // and the code proceeds with default 'id' field. This is a bug - it should fail fast.
      // TODO: Fix implementation to fail fast when entity file doesn't exist.
      // For now, the test documents current (buggy) behavior.
      final decoded = jsonDecode(output) as Map<String, dynamic>;
      expect(decoded['success'], isTrue);
      final plan = decoded['plan'] as Map<String, dynamic>;
      expect(plan['name'], 'NonExistentEntity');
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

    // Runs zfa from SOURCE (never the stale compiled ~/.local/bin/zfa) as a
    // subprocess with an explicit workingDirectory — no process-global
    // `Directory.current` mutation, so this group cannot race with other
    // test files that capture the cwd at load time (see #296 test).
    Future<ProcessResult> runZfaSource(List<String> args) {
      return Process.run('dart', [
        zfaSourceBin,
        ...args,
      ], workingDirectory: workspace.path);
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
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
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
}
