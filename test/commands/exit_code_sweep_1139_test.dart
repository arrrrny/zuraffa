import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/api_command.dart';
import 'package:zuraffa/src/commands/controller_command.dart';
import 'package:zuraffa/src/commands/feature_command.dart';
import 'package:zuraffa/src/commands/gql_command.dart';
import 'package:zuraffa/src/commands/graphql_command.dart';
import 'package:zuraffa/src/commands/gym_command.dart';
import 'package:zuraffa/src/commands/presenter_command.dart';
import 'package:zuraffa/src/commands/sync_command.dart';
import 'package:zuraffa/src/commands/view_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/plugins/api/api_plugin.dart';
import 'package:zuraffa/src/plugins/api/capabilities/create_api_bridge_capability.dart';
import 'package:zuraffa/src/plugins/controller/capabilities/create_controller_capability.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/gql/capabilities/create_gql_capability.dart';
import 'package:zuraffa/src/plugins/gql/gql_plugin.dart';
import 'package:zuraffa/src/plugins/graphql/capabilities/create_graphql_capability.dart';
import 'package:zuraffa/src/plugins/graphql/graphql_plugin.dart';
import 'package:zuraffa/src/plugins/gym/capabilities/create_gym_capability.dart';
import 'package:zuraffa/src/plugins/gym/gym_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/capabilities/create_presenter_capability.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';
import 'package:zuraffa/src/plugins/shadcn/commands/shadcn_command.dart';
import 'package:zuraffa/src/plugins/shadcn/shadcn_plugin.dart';
import 'package:zuraffa/src/plugins/sync/capabilities/create_sync_capability.dart';
import 'package:zuraffa/src/plugins/sync/sync_plugin.dart';
import 'package:zuraffa/src/plugins/view/capabilities/create_view_capability.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';
import 'package:zuraffa/src/plugins/feature/feature_plugin.dart';

/// Bug #1139 — exit-code sweep (part of EPIC #1132: Machine Contract).
///
/// The CLI's "errors are an API" contract: a command body that reports a
/// failure must never exit 0, and a command body handed bad input must
/// signal a usage error (64). The #856 fix (state/service/repository/
/// provider/sqlite/test) established the pattern — bare invocation reports
/// subcommand usage with exitCode = 64, failure paths exitCode = 1.
///
/// This suite pins the same honesty onto every command body the bug
/// record names whose failure paths still lie. Bare-invocation guards for
/// the #856 family were already ported; what remains is the failure half.
Future<String> captureOutput(FutureOr<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

/// Capability that reports an honest failure without touching the
/// filesystem — drives each command's failure branch deterministically.
class _FailingCapability extends CreateControllerCapability {
  _FailingCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(
        success: false,
        files: const [],
        message: 'simulated generation failure (1139 sweep)',
      );
}

class _FailingPresenterCapability extends CreatePresenterCapability {
  _FailingPresenterCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, files: const []);
}

class _FailingGqlCapability extends CreateGqlCapability {
  _FailingGqlCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, files: const []);
}

class _FailingGraphqlCapability extends CreateGraphqlCapability {
  _FailingGraphqlCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, files: const []);
}

class _FailingGymCapability extends CreateGymCapability {
  _FailingGymCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, files: const []);
}

class _FailingSyncCapability extends CreateSyncCapability {
  _FailingSyncCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, files: const []);
}

class _FailingViewCapability extends CreateViewCapability {
  _FailingViewCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, files: const []);
}

class _FailingApiCapability extends CreateApiBridgeCapability {
  _FailingApiCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: false, files: const [], message: 'boom');
}

class _FailingControllerPlugin extends ControllerPlugin {
  _FailingControllerPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingCapability(this)];
}

class _FailingPresenterPlugin extends PresenterPlugin {
  _FailingPresenterPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [
    _FailingPresenterCapability(this),
  ];
}

class _FailingGqlPlugin extends GqlPlugin {
  _FailingGqlPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingGqlCapability(this)];
}

class _FailingGraphqlPlugin extends GraphqlPlugin {
  _FailingGraphqlPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingGraphqlCapability(this)];
}

class _FailingGymPlugin extends GymPlugin {
  _FailingGymPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingGymCapability(this)];
}

class _FailingSyncPlugin extends SyncPlugin {
  _FailingSyncPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingSyncCapability(this)];
}

class _FailingViewPlugin extends ViewPlugin {
  _FailingViewPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingViewCapability(this)];
}

class _FailingApiPlugin extends ApiPlugin {
  _FailingApiPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingApiCapability(this)];
}

/// ApiPlugin with no bridge capability at all — drives the command's
/// "internal error" branch (capability registry came up empty).
class _CapabilitylessApiPlugin extends ApiPlugin {
  _CapabilitylessApiPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => const [];
}

/// Command bodies whose parsed [argResults] can be injected directly — run()
/// is only reachable programmatically for PluginCommand bodies (package:args
/// rejects positional shapes at dispatch), exactly like the #977 datasource
/// harness.
mixin _InjectableArgs on Command<void> {
  ArgResults? injected;

  void accept(List<String> args) => injected = argParser.parse(args);
}

class _InjectableControllerCommand extends ControllerCommand
    with _InjectableArgs {
  _InjectableControllerCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

class _InjectablePresenterCommand extends PresenterCommand
    with _InjectableArgs {
  _InjectablePresenterCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

class _InjectableGqlCommand extends GqlCommand with _InjectableArgs {
  _InjectableGqlCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

class _InjectableGraphqlCommand extends GraphqlCommand with _InjectableArgs {
  _InjectableGraphqlCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

class _InjectableGymCommand extends GymCommand with _InjectableArgs {
  _InjectableGymCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

class _InjectableSyncCommand extends SyncCommand with _InjectableArgs {
  _InjectableSyncCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

class _InjectableViewCommand extends ViewCommand with _InjectableArgs {
  _InjectableViewCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

class _InjectableApiCommand extends ApiCommand with _InjectableArgs {
  _InjectableApiCommand(super.plugin);

  @override
  ArgResults? get argResults => injected ?? super.argResults;
}

void main() {
  tearDown(() {
    exitCode = 0;
  });

  group('#1139 failure paths exit 1 (in-process, programmatic run())', () {
    Future<void> expectFailureExit1(
      Command<void> command, {
      List<String> args = const ['Product'],
    }) async {
      exitCode = 0;
      final injectable = command as _InjectableArgs;
      injectable.accept(args);
      final output = await captureOutput(() => command.run());
      expect(
        exitCode,
        1,
        reason: 'a failed generation must exit 1, not 0 — output was:\n$output',
      );
    }

    test('controller exits 1 when generation fails', () async {
      final command = _InjectableControllerCommand(
        _FailingControllerPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    test('presenter exits 1 when generation fails', () async {
      final command = _InjectablePresenterCommand(
        _FailingPresenterPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    test('gql exits 1 when generation fails', () async {
      final command = _InjectableGqlCommand(
        _FailingGqlPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    test('graphql exits 1 when generation fails', () async {
      final command = _InjectableGraphqlCommand(
        _FailingGraphqlPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    test('gym exits 1 when generation fails', () async {
      final command = _InjectableGymCommand(
        _FailingGymPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    // 'observer exits 1 when generation fails' removed (issue #1149): the
    // observer plugin is gone; the command name now delivers an exit-64
    // removal verdict — covered in test/commands/observer_removed_test.dart.

    test('sync exits 1 when generation fails', () async {
      final command = _InjectableSyncCommand(
        _FailingSyncPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    test('view exits 1 when generation fails', () async {
      final command = _InjectableViewCommand(
        _FailingViewPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    test('api exits 1 when generation fails', () async {
      final command = _InjectableApiCommand(
        _FailingApiPlugin(outputDir: 'lib/src'),
      );
      await expectFailureExit1(command);
    });

    test(
      'api exits 1 when the bridge capability is missing (internal error)',
      () async {
        exitCode = 0;
        final command = _InjectableApiCommand(
          _CapabilitylessApiPlugin(outputDir: 'lib/src'),
        );
        command.accept(['Product']);
        final output = await captureOutput(() => command.run());
        expect(
          exitCode,
          1,
          reason: 'an internal error must not exit 0 — output was:\n$output',
        );
        expect(output, contains('Internal error'));
      },
    );
  });

  group('#1139 usage errors exit 64 (dispatch level)', () {
    late CommandRunner<void> runner;
    late CommandRunner<void> featureRunner;

    setUp(() {
      final out = 'lib/src';
      runner = CommandRunner<void>('zfa', 'test runner');
      runner.addCommand(
        ShadcnCommand(
          ShadcnPlugin(outputDir: out, options: const GeneratorOptions()),
        ),
      );
      runner.addCommand(
        GraphqlCommand(
          GraphqlPlugin(outputDir: out, options: const GeneratorOptions()),
        ),
      );

      featureRunner = CommandRunner<void>('zfa', 'test runner');
      featureRunner.addCommand(
        FeatureCommand(
          FeaturePlugin(outputDir: out, options: const GeneratorOptions()),
        ),
      );
    });

    test('shadcn rejects an unknown layout positional with exit 64', () async {
      exitCode = 0;
      // Invalid layout: the command must refuse before generating.
      // The zuraffa repo itself is a pure-Dart package, so the builder's
      // pure-Dart guard means nothing is written even in the RED state.
      await runner.run(['shadcn', 'banana', 'Product']);
      expect(
        exitCode,
        64,
        reason: 'an unknown layout is a usage error, not a silent generation',
      );
    });

    test(
      'graphql introspect rejects malformed --headers JSON with exit 64',
      () async {
        exitCode = 0;
        await runner.run([
          'graphql',
          'introspect',
          'https://example.invalid/graphql',
          '--headers={not json',
        ]);
        expect(
          exitCode,
          64,
          reason: 'malformed --headers JSON is a usage error, not exit 0',
        );
      },
    );

    test(
      'graphql introspect rejects a URL-less endpoint with exit 64',
      () async {
        exitCode = 0;
        await runner.run(['graphql', 'introspect', 'not-a-url']);
        expect(
          exitCode,
          64,
          reason: 'an endpoint without scheme/authority is a usage error',
        );
      },
    );

    test('feature exits 64 when a mode is given without a name', () async {
      exitCode = 0;
      final output = <String>[];
      await runZoned(
        () => featureRunner.run(['feature', 'state']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );
      expect(
        exitCode,
        64,
        reason: 'missing feature name must be a usage error, not exit 0',
      );
      expect(output.join('\n'), contains('Missing feature name'));
    });
  });

  group('#1139 graphql introspect failure exits 1', () {
    late CommandRunner<void> runner;

    setUp(() {
      final out = 'lib/src';
      runner = CommandRunner<void>('zfa', 'test runner');
      runner.addCommand(
        GraphqlCommand(
          GraphqlPlugin(outputDir: out, options: const GeneratorOptions()),
        ),
      );
    });

    test('unreachable endpoint exits 1 (never a lying exit 0)', () async {
      exitCode = 0;
      final output = <String>[];
      await runZoned(
        () => runner.run(['graphql', 'introspect', 'http://127.0.0.1:1/gql']),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => output.add(line),
        ),
      );
      expect(
        exitCode,
        1,
        reason:
            'introspection failure is a real failure — output was:\n${output.join('\n')}',
      );
      expect(output.join('\n'), contains('Failed to introspect'));
    });
  });

  group('#1139 real-CLI subprocess paths (flutter-flavored sandbox)', () {
    // These paths depend on the *target project's* flavor (pubspec.yaml
    // declaring `flutter:`), which the shared test process cannot mutate
    // safely (cross-suite cwd races, issue #1096). A subprocess running the
    // real CLI against a sandbox pubspec is the honest harness.
    late Directory sandbox;
    late String zfaScript;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('zuraffa_1139_');
      File('${sandbox.path}/pubspec.yaml').writeAsStringSync(
        'name: sandbox\nenvironment:\n  sdk: ^3.11.0\ndependencies:\n'
        '  flutter:\n    sdk: flutter\n',
      );
      final script = File('bin/zfa.dart');
      zfaScript = script.absolute.path;
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('module exits 1 when the package directory already exists', () async {
      Directory('${sandbox.path}/zuraffa_feature_toy').createSync();
      final result = await Process.run(Platform.resolvedExecutable, [
        zfaScript,
        'module',
        'toy',
      ], workingDirectory: sandbox.path);
      expect(
        result.exitCode,
        1,
        reason:
            'module scaffold over an existing package must exit 1 — '
            'stdout:\n${result.stdout}',
      );
      expect(result.stdout, contains('already exists'));
    });

    test(
      'shadcn exits 1 when generation fails (blocked output tree)',
      () async {
        // A FILE where the generator must create the `lib` directory makes
        // every write attempt throw a FileSystemException inside manager.run
        // — the command's catch block must translate that into exit 1, not a
        // lying exit 0. (Sandbox pubspec declares `flutter:` so the builder's
        // pure-Dart guard does not skip generation.)
        File('${sandbox.path}/lib').writeAsStringSync('not a directory\n');
        final result = await Process.run(Platform.resolvedExecutable, [
          zfaScript,
          'shadcn',
          'list',
          'Product',
        ], workingDirectory: sandbox.path);
        expect(
          result.exitCode,
          1,
          reason:
              'a generation failure must exit 1, not 0 — '
              'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        expect(result.stdout, contains('Failed to generate widget'));
      },
    );
  });
}
