import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/datasource_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/capabilities/create_datasource_capability.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Spec #977 — honest exit semantics for the standalone `zfa datasource`
/// path and the structured `hasService` skip.
///
/// Regression-proves (failing-first):
/// 1. bare `zfa datasource` (and flags-but-no-entity) exits 64 via
///    `reportSubcommandUsage()` — never a lying exit 0;
/// 2. the failure branch exits 1 and prints a `--> fix:` line with the
///    reason — never a lying exit 0;
/// 3. a `hasService` request is a *structured skip*
///    (`ExecutionResult(success: false, message: <reason>)`), never an
///    empty success;
/// 4. a success result carrying zero files (non-dry-run) is refused with
///    exit 1 (#769 zero-files guard mirrored onto the standalone path);
/// 5. emission semantics of `DataSourcePlugin.generate` are unchanged
///    (still returns `[]` for `hasService` — the contract around it
///    changed, not the emission).
Future<String> captureOutput(Future<void> Function() body) async {
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

/// Capability that reports an honest failure (e.g. a generator that
/// threw), used to drive the command's failure branch deterministically.
class _FailingCreateCapability extends CreateDataSourceCapability {
  _FailingCreateCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(
        success: false,
        files: const [],
        message: 'simulated generation failure: entity contract violated',
      );
}

/// Capability that claims success while emitting nothing — exactly the
/// lie the #769 zero-files guard exists to catch.
class _EmptySuccessCapability extends CreateDataSourceCapability {
  _EmptySuccessCapability(super.plugin);

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(
        success: true,
        files: const [],
        data: {'generatedFiles': <GeneratedFile>[]},
      );
}

class _FailingPlugin extends DataSourcePlugin {
  _FailingPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_FailingCreateCapability(this)];
}

class _EmptySuccessPlugin extends DataSourcePlugin {
  _EmptySuccessPlugin({required super.outputDir});

  @override
  List<ZuraffaCapability> get capabilities => [_EmptySuccessCapability(this)];
}

/// DataSourceCommand whose parsed [argResults] can be injected directly.
///
/// package:args rejects every entity-positional shape for a command that
/// registers subcommands ("Could not find a subcommand") before run()
/// executes, so run()'s own contract — including its failure branch and
/// receipts — is only exercisable through direct programmatic invocation
/// with a hand-parsed ArgResults, exactly the host-embedding path the
/// base-class contract documents.
class _InjectableDataSourceCommand extends DataSourceCommand {
  _InjectableDataSourceCommand(super.plugin);

  ArgResults? injected;

  @override
  ArgResults? get argResults => injected ?? super.argResults;

  void accept(List<String> args) => injected = argParser.parse(args);
}

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_977_exit_');
    outputDir = '${tempDir.path}/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    exitCode = 0;
  });

  group('lie #1 — missing args never exit 0', () {
    // Through the real CLI, package:args rejects a bare plugin command
    // (or any flags-but-no-positional shape) with a dispatch-level
    // UsageException before run() executes; CliRunner maps that to
    // _exit(64) (cli_runner.dart). run() itself is reachable through
    // direct programmatic invocation (MCP embedding, hosts) — that is
    // the branch datasource_command.dart:50-53 owns, and it must exit
    // 64 via reportSubcommandUsage(), never fall through as success.
    test(
      'programmatic run() with no entity exits 64 via reportSubcommandUsage',
      () async {
        exitCode = 0;
        final plugin = DataSourcePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(),
        );
        final command = DataSourceCommand(plugin);
        // Direct programmatic invocation: argResults is null exactly as the
        // base-class contract documents for hosts that call run() directly.
        // run() must treat the missing entity as a usage error, never fall
        // through looking like a success.
        final output = await captureOutput(() => command.run());

        expect(exitCode, 64, reason: 'bare command must signal usage error 64');
        expect(output, contains('Usage'));
        expect(output, contains('--help'));
      },
    );

    test(
      'dispatch-level: real CLI rejects bare `datasource` with Missing subcommand',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(['datasource']);

        expect(out, contains('Missing subcommand'));
        expect(out, contains('zfa datasource <subcommand>'));
      },
    );
  });

  group('lie #2 — failure branch never exits 0', () {
    test('failure exits 1 and prints --> fix: with the reason', () async {
      exitCode = 0;
      final command = _InjectableDataSourceCommand(
        _FailingPlugin(outputDir: outputDir),
      );
      command.accept(['Product']);

      final output = await captureOutput(() => command.run());

      expect(exitCode, 1, reason: 'a failed generation must exit 1, not 0');
      expect(output, contains('--> fix:'));
      expect(output, contains('simulated generation failure'));
    });
  });

  group('structured hasService skip (#769 contract)', () {
    test('capability.execute reports success:false with a reason', () async {
      final plugin = DataSourcePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final capability = plugin.capabilities
          .whereType<CreateDataSourceCapability>()
          .first;

      final result = await capability.execute({
        'name': 'Product',
        'useService': true,
        'local': false,
        'remote': true,
      });

      expect(result.success, isFalse, reason: 'a skip is not a success');
      expect(result.message, isNotNull);
      expect(result.message, contains('service'));
      expect(result.files, isEmpty);
      // Nothing may be emitted for a skipped request.
      expect(Directory('$outputDir/data').existsSync(), isFalse);
    });

    test('use-service spelling is honored too', () async {
      final plugin = DataSourcePlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(),
      );
      final capability = plugin.capabilities
          .whereType<CreateDataSourceCapability>()
          .first;

      final result = await capability.execute({
        'name': 'Product',
        'use-service': true,
      });

      expect(result.success, isFalse);
      expect(result.message, isNotNull);
    });

    test(
      'emission semantics unchanged: plugin.generate still returns [] for hasService',
      () async {
        final plugin = DataSourcePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(),
        );

        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            generateDataSource: true,
            useService: true,
            outputDir: outputDir,
          ),
        );

        expect(files, isEmpty);
        expect(Directory('$outputDir/data').existsSync(), isFalse);
      },
    );
  });

  group(
    'zero-files success is refused on the standalone path (#769 mirror)',
    () {
      test('success:true with zero files exits 1 (non-dry-run)', () async {
        exitCode = 0;
        final command = _InjectableDataSourceCommand(
          _EmptySuccessPlugin(outputDir: outputDir),
        );
        command.accept(['Product']);

        final output = await captureOutput(() => command.run());

        expect(
          exitCode,
          1,
          reason: 'a success result with zero generated files must not exit 0',
        );
        expect(output, contains('No files were generated'));
      });
    },
  );
}
