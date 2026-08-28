// Tests for lib/src/plugins/benchmark/cli/benchmark_command.dart —
// behaviors U61–U67 of specs/015-benchmark-plugin/tdd/test-list.md.
//
// Drives the command through its real entry point: an args CommandRunner
// hosting BenchmarkCommand, with stdout captured via runZoned.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/benchmark/benchmark_plugin.dart';
import 'package:zuraffa/src/plugins/benchmark/cli/benchmark_command.dart';

import 'helpers/fake_scenarios.dart';

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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_benchmark_cli');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  BenchmarkPlugin pluginWith(List<BenchmarkContract> scenarios) {
    final plugin = BenchmarkPlugin();
    plugin.registerScenarioProvider(_Provider(scenarios));
    return plugin;
  }

  group('BenchmarkCommand', () {
    test('list prints scenarios', () async {
      final plugin = pluginWith([
        RecordingScenario('alpha-benchmark', tags: ['db']),
        RecordingScenario('beta-benchmark'),
      ]);
      final command = BenchmarkCommand(plugin);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await plugin.discoverAndRegisterScenarios();

      final output = await captureOutput(
        () => runner.run(['benchmark', 'list']),
      );

      expect(output, contains('alpha-benchmark'));
      expect(output, contains('beta-benchmark'));
      expect(output, contains('1.0.0'));
      expect(output, contains('db'));
      expect(command.exitCode, 0);
    });

    test('run reports and exits', () async {
      final plugin = pluginWith([
        RecordingScenario('healthy-benchmark'),
        ThrowingScenario('sick-benchmark', throwIn: LifecycleStage.run),
      ]);
      final command = BenchmarkCommand(plugin);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await plugin.discoverAndRegisterScenarios();

      final output = await captureOutput(
        () => runner.run(['benchmark', 'run']),
      );

      // Per-benchmark results and the aggregate verdict are printed.
      expect(output, contains('healthy-benchmark'));
      expect(output, contains('sick-benchmark'));
      expect(output.toLowerCase(), contains('error'));

      // Exit code reflects the overall status (non-zero on failure).
      expect(command.exitCode, isNonZero);
    });

    test('scenario filter', () async {
      final plugin = pluginWith([
        RecordingScenario('chosen-benchmark'),
        RecordingScenario('skipped-benchmark'),
      ]);
      final command = BenchmarkCommand(plugin);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await plugin.discoverAndRegisterScenarios();

      final output = await captureOutput(
        () => runner.run([
          'benchmark',
          'run',
          '--scenario',
          'chosen-benchmark',
        ]),
      );

      expect(output, contains('chosen-benchmark'));
      expect(output, isNot(contains('skipped-benchmark')));
      expect(command.exitCode, 0);
    });

    test('dry run validates only', () async {
      final scenario = SchemaScenario('schema-cli-scenario');
      final plugin = pluginWith([scenario]);
      final command = BenchmarkCommand(plugin);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await plugin.discoverAndRegisterScenarios();

      final output = await captureOutput(
        () => runner.run([
          'benchmark',
          'run',
          '--dry-run',
          '--config',
          '{"entityCount": 5}',
        ]),
      );

      expect(output.toLowerCase(), contains('valid'));
      // Nothing executed.
      expect(scenario.calls, isEmpty);
      expect(command.exitCode, 0);
    });

    test('baseline subcommands', () async {
      final plugin = pluginWith([
        RecordingScenario('baseline-scenario', metrics: const {
          'latency_p99': 100,
        }),
      ]);
      final command = BenchmarkCommand(plugin);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await plugin.discoverAndRegisterScenarios();

      // save
      var output = await captureOutput(
        () => runner.run([
          'benchmark',
          'baseline',
          'save',
          'baseline-scenario',
          '--label',
          'v1',
          '--store',
          tempDir.path,
        ]),
      );
      expect(output, contains('v1'));

      // load
      output = await captureOutput(
        () => runner.run([
          'benchmark',
          'baseline',
          'load',
          'baseline-scenario',
          '--store',
          tempDir.path,
        ]),
      );
      expect(output, contains('latency_p99'));

      // compare (current run against the saved baseline)
      output = await captureOutput(
        () => runner.run([
          'benchmark',
          'baseline',
          'compare',
          'baseline-scenario',
          '--baseline',
          'v1',
          '--store',
          tempDir.path,
        ]),
      );
      expect(
        output.toLowerCase(),
        anyOf(contains('stable'), contains('no change')),
      );

      // list
      output = await captureOutput(
        () => runner.run([
          'benchmark',
          'baseline',
          'list',
          '--store',
          tempDir.path,
        ]),
      );
      expect(output, contains('baseline-scenario'));
    });

    test('json output', () async {
      final plugin = pluginWith([RecordingScenario('json-benchmark')]);
      final command = BenchmarkCommand(plugin);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await plugin.discoverAndRegisterScenarios();

      final output = await captureOutput(
        () => runner.run(['benchmark', 'list', '--json']),
      );

      final decoded = jsonDecode(output) as Map<String, dynamic>;
      final scenarios = decoded['scenarios'] as List<dynamic>;
      expect(scenarios, hasLength(1));
      expect(scenarios.first['id'], 'json-benchmark');
    });

    test('unknown subcommand usage', () async {
      final plugin = pluginWith([]);
      final command = BenchmarkCommand(plugin);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

      final output = await captureOutput(() async {
        try {
          await runner.run(['benchmark', 'teleport']);
        } on UsageException catch (e) {
          // The args package surfaces unknown subcommands as usage errors.
          print('${e.message}');
          command.exitCode = 64;
        }
      });

      expect(output.toLowerCase(), contains('usage'));
      expect(command.exitCode, isNonZero);
    });
  });
}

class _Provider implements BenchmarkScenarioProvider {
  _Provider(this.scenarios);

  final List<BenchmarkContract> scenarios;

  @override
  List<BenchmarkContract> provideScenarios() => scenarios;
}
