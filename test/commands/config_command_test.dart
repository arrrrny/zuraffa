/// CLI-surface tests for `zfa config init` argument handling (PR #1579
/// review): `_ConfigCommand` feeds the handler raw args
/// (`ArgParser.allowAnything()`), so `--help` and misspelled flags reach
/// `_handleInit` instead of being consumed by the parser — they must not
/// silently initialize the current directory.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/config/zfa_config.dart';

void main() {
  late CliRunner runner;
  late Directory tmp;

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    tmp = await Directory.systemTemp.createTemp('config_cmd_');
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  File configFile() => File(p.join(tmp.path, '.zfa.json'));

  Future<String> driveInit(List<String> args) =>
      runner.runCapturing(['-C', tmp.path, 'config', 'init', ...args]);

  test('config init --help prints help and writes no config', () async {
    final out = await driveInit(['--help']);

    expect(out, contains('zfa config - Manage ZFA configuration'));
    expect(
      configFile().existsSync(),
      isFalse,
      reason: 'a help request must never create .zfa.json',
    );
    expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
  });

  test('config init -h prints help and writes no config', () async {
    final out = await driveInit(['-h']);

    expect(out, contains('zfa config - Manage ZFA configuration'));
    expect(configFile().existsSync(), isFalse);
    expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
  });

  test(
    'config init rejects an unknown option instead of initializing',
    () async {
      final out = await driveInit(['--minmal']);

      expect(out, contains('Unknown init option: --minmal'));
      expect(
        configFile().existsSync(),
        isFalse,
        reason: 'a rejected flag must not initialize the current directory',
      );
      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.usage);
    },
  );

  test('config init still accepts --minimal after the option gate', () async {
    final out = await driveInit(['--minimal']);

    expect(out, contains('Minimal mode'));
    final config = ZfaConfig.load(projectRoot: tmp.path);
    expect(config, isNotNull);
    expect(
      config!.pluginDefaults.values.every((enabled) => !enabled),
      isTrue,
      reason: '--minimal must keep writing the all-off map',
    );
  });

  test('config init reports an all-false legacy defaults block', () async {
    // The exact shape the pre-fix `config init` wrote: every builtin key
    // explicitly false — indistinguishable from intent in the JSON alone.
    await configFile().writeAsString(
      jsonEncode({
        'plugins': {
          'defaults': {
            for (final id in ZfaConfig().pluginDefaults.keys) id: false,
          },
          'disabled': <String>[],
        },
      }),
    );

    final out = await driveInit([]);

    expect(out, contains('already exists'));
    expect(out, contains('all-false'));
    expect(out, contains('zfa config set'));
  });

  test('config init stays quiet on a stack-default config', () async {
    await ZfaConfig.init(projectRoot: tmp.path);

    final out = await driveInit([]);

    expect(out, contains('already exists'));
    expect(
      out,
      isNot(contains('all-false')),
      reason: 'a config written by the fixed init is not a legacy default',
    );
  });
}
