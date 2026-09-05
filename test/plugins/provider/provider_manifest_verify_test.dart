import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/manifest_command.dart';
import 'package:zuraffa/src/commands/base_plugin_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/cli_aware_plugin.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';

/// Spec 979, order 3 — `zfa manifest --verify` certifies the flag surface.
///
/// After the provider dead-flag purge, the provider command registers ZERO
/// plugin-specific parent flags, so `zfa manifest --verify provider` must
/// exit 0 and print the certification. A command that still registers a
/// parent-level flag its run() never reads (the #876 "flags that lie"
/// family — a synthetic probe here) must be reported as a dead-flag
/// finding with an actionable `--> fix:` line and exit 1.
void main() {
  test('provider flag surface certifies green after the purge', () async {
    final registry = PluginRegistry()
      ..register(
        ProviderPlugin(outputDir: 'lib/src', options: const GeneratorOptions()),
      );
    final command = ManifestCommand(registry);

    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
    final lines = <String>[];
    exitCode = 0;
    await _capture(
      () => runner.run(['manifest', '--verify', 'provider']),
      lines.add,
    );
    final code = exitCode;
    exitCode = 0;

    expect(code, equals(0));
    final text = lines.join('\n');
    expect(text, contains('provider'));
    expect(text, contains('certified'));
  });

  test('a dead parent-level flag is a finding with a fix line and exit 1 '
      '(the certification has teeth)', () async {
    final registry = PluginRegistry()
      ..register(
        ProviderPlugin(outputDir: 'lib/src', options: const GeneratorOptions()),
      )
      ..register(_DeadFlagProbePlugin());
    final command = ManifestCommand(registry);

    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
    final lines = <String>[];
    exitCode = 0;
    await _capture(
      () => runner.run(['manifest', '--verify', 'probe']),
      lines.add,
    );
    final code = exitCode;
    exitCode = 0;

    expect(code, equals(1));
    final text = lines.join('\n');
    expect(
      text,
      contains('dead-flag'),
      reason: 'the finding kind must be named',
    );
    expect(text, contains('--fake-methods'));
    expect(text, contains('--> fix:'));
  });

  test(
    'unscoped --verify scans every CLI-aware plugin in the registry',
    () async {
      final registry = PluginRegistry()
        ..register(
          ProviderPlugin(
            outputDir: 'lib/src',
            options: const GeneratorOptions(),
          ),
        )
        ..register(_DeadFlagProbePlugin());
      final command = ManifestCommand(registry);

      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      final lines = <String>[];
      exitCode = 0;
      await _capture(() => runner.run(['manifest', '--verify']), lines.add);
      final code = exitCode;
      exitCode = 0;

      // The dead probe is found without scoping.
      expect(code, equals(1));
      expect(lines.join('\n'), contains('--fake-methods'));
    },
  );
}

Future<void> _capture(
  Future<void> Function() body,
  void Function(String) sink,
) {
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, String line) => sink(line),
    ),
  );
}

/// A synthetic plugin whose command registers a parent-level flag that
/// run() never reads — the exact #876 dead-flag shape the certification
/// must catch.
class _DeadFlagProbePlugin extends ZuraffaPlugin implements CliAwarePlugin {
  @override
  String get id => 'probe';

  @override
  String get name => 'Dead Flag Probe Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => _DeadFlagProbeCommand(this);
}

class _DeadFlagProbeCommand extends PluginCommand {
  _DeadFlagProbeCommand(super.plugin) {
    argParser.addOption(
      'fake-methods',
      help: 'Parsed, advertised, never read — the dead-flag probe',
    );
  }

  @override
  String get name => 'probe';

  @override
  String get description => 'Probe command with one dead parent flag';

  @override
  Future<void> run() async {
    // Like the provider/repository/service commands on master (bug #856):
    // run() never reads --fake-methods.
    reportSubcommandUsage();
  }
}
