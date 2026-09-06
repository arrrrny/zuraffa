import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/manifest_command.dart';
import 'package:zuraffa/src/commands/base_plugin_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/plugin_system/cli_aware_plugin.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';

/// SPEC 917 — `zfa manifest --verify` is the full treaty gate:
/// manifest inputSchemas ↔ CLI flags ↔ help text, with drift = exit 3
/// (the canonical contract-drift code, VISION §3).
///
/// The #904 audit sites are the seed fixture list: every drift shape that
/// audit found in the wild is re-introduced here as a synthetic probe and
/// the gate must catch it with a precise finding + `--> fix:` line.
///
/// Legs:
///   1. resolution — every advertised capability must resolve in the CLI
///      command tree (the #763 phantom-capability family);
///   2. schema→flags — every `inputSchema.properties` entry (required per
///      #902, optional per #904) must be accepted by the serving parser
///      (camelCase → kebab-case);
///   3. help text — every schema-derived flag must appear in the serving
///      command's usage/help surface;
///   4. dead flags — PluginCommand parent options outside
///      [PluginCommand.consumedParentFlags] (the #876 family, scoped to
///      the command family the check was designed for).
void main() {
  Future<(int, String)> verify({
    required PluginRegistry registry,
    List<String> rest = const [],
    bool jsonFormat = false,
  }) async {
    final command = ManifestCommand(registry);
    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
    final lines = <String>[];
    exitCode = 0;
    await runZoned(
      () => runner.run([
        'manifest',
        '--verify',
        if (jsonFormat) '--format=json',
        ...rest,
      ]),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, String line) => lines.add(line),
      ),
    );
    final code = exitCode;
    exitCode = 0;
    return (code, lines.join('\n'));
  }

  test('a conformant plugin certifies green with exit 0', () async {
    final registry = PluginRegistry()..register(_ConformantPlugin());
    final (code, out) = await verify(registry: registry, rest: ['conformant']);
    expect(code, 0, reason: out);
    expect(out, contains('certified'));
  });

  test('drift exits the canonical contract-drift code 3 (was 1)', () async {
    final registry = PluginRegistry()..register(_SchemaFlagProbePlugin());
    final (code, out) = await verify(registry: registry, rest: ['probe904']);
    expect(code, 3, reason: out);
  });

  test('#904 seed fixture: schema-declared optional flag the parser rejects '
      '(feature scaffold --use-mock shape) is a precise finding', () async {
    final registry = PluginRegistry()..register(_SchemaFlagProbePlugin());
    final (code, out) = await verify(registry: registry, rest: ['probe904']);
    expect(code, 3);
    expect(out, contains('schema-flag-unaccepted'));
    expect(out, contains('--use-mock'));
    expect(out, contains('--> fix:'));
  });

  test('#904 seed fixture: camelCase schema property maps to kebab-case flag '
      '(outputDir → --output-dir shape)', () async {
    final registry = PluginRegistry()..register(_CamelCaseProbePlugin());
    final (code, out) = await verify(registry: registry, rest: ['camel904']);
    expect(code, 3);
    expect(out, contains('--output-dir'));
  });

  test('help-text leg: a flag the usage hides is drift', () async {
    final registry = PluginRegistry()..register(_HiddenHelpProbePlugin());
    final (code, out) = await verify(registry: registry, rest: ['hidden904']);
    expect(code, 3);
    expect(out, contains('help-text-drift'));
  });

  test('dead-flag leg (#876 family) stays scoped and actionable', () async {
    final registry = PluginRegistry()..register(_DeadFlagProbePlugin());
    final (code, out) = await verify(registry: registry, rest: ['probe876']);
    expect(code, 3);
    expect(out, contains('dead-flag'));
    expect(out, contains('--fake-methods'));
    expect(out, contains('--> fix:'));
  });

  test('--format json emits one machine-verifiable document', () async {
    final registry = PluginRegistry()
      ..register(_ConformantPlugin())
      ..register(_SchemaFlagProbePlugin());
    final (code, out) = await verify(
      registry: registry,
      rest: ['probe904'],
      jsonFormat: true,
    );
    expect(code, 3);
    final doc = jsonDecode(out.trim().split('\n').last) as Map<String, dynamic>;
    // EPIC 1150: the envelope wraps the manifest-verify payload in `data`.
    expect(doc['schema'], 'zuraffa.verdict.v1');
    expect(doc['result'], 'error');
    expect(doc['exit_class'], 3);
    final payload = doc['data'] as Map<String, dynamic>;
    expect(payload['ok'], false);
    expect(payload['exit_code'], 3);
    final findings = payload['findings'] as List<dynamic>;
    expect(
      findings.any(
        (f) => (f as Map<String, dynamic>)['kind'] == 'schema-flag-unaccepted',
      ),
      isTrue,
      reason: out,
    );
    expect(doc['fix'], isNotNull);
  });

  test('clean pass under --format json is ok:true with exit_code 0', () async {
    final registry = PluginRegistry()..register(_ConformantPlugin());
    final (code, out) = await verify(
      registry: registry,
      rest: ['conformant'],
      jsonFormat: true,
    );
    expect(code, 0);
    final doc = jsonDecode(out.trim().split('\n').last) as Map<String, dynamic>;
    // EPIC 1150: the envelope wraps the manifest-verify payload in `data`.
    expect(doc['schema'], 'zuraffa.verdict.v1');
    expect(doc['result'], 'ok');
    expect(doc['exit_class'], 0);
    final payload = doc['data'] as Map<String, dynamic>;
    expect(payload['ok'], true);
    expect(payload['exit_code'], 0);
  });

  test('the live repo certifies green after the #904/#876 fixes', () async {
    // The seed fixture list is FIXED in this same spec; the gate must pass
    // on the repo with zero drift (#776 acceptance criterion 1).
    final registry = PluginRegistry()
      ..register(
        ProviderPlugin(outputDir: 'lib/src', options: const GeneratorOptions()),
      );
    final (code, out) = await verify(registry: registry, rest: ['provider']);
    expect(code, 0, reason: out);
  });
}

Future<void> _noopSink(String _) async {}

/// A conformant plugin: one capability whose schema is fully accepted by
/// the derived subcommand parser, no dead parent flags.
class _ConformantPlugin extends ZuraffaPlugin implements CliAwarePlugin {
  @override
  String get id => 'conformant';

  @override
  String get name => 'Conformant Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => _ConformantCommand(this);

  @override
  List<ZuraffaCapability> get capabilities => [_ConformantCapability()];
}

class _ConformantCommand extends PluginCommand {
  _ConformantCommand(super.plugin);

  @override
  String get description => 'Conformant probe';
}

class _ConformantCapability implements ZuraffaCapability {
  @override
  String get name => 'create_thing';

  @override
  String get description => 'Conformant capability (schema = parser).';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'conformant',
    pluginId: 'conformant',
    capabilityName: name,
    args: args,
    changes: const [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: true, files: const []);
}

/// The #904 shape: a hand-rolled command whose capability schema declares
/// `use-mock` (boolean) but whose parser rejects it — exactly the live
/// drift `zfa feature scaffold --use-mock` had before the fix.
class _SchemaFlagProbePlugin extends ZuraffaPlugin implements CliAwarePlugin {
  @override
  String get id => 'probe904';

  @override
  String get name => '904 Probe Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => _SchemaFlagProbeCommand(this);

  @override
  List<ZuraffaCapability> get capabilities => [_ProbeCapability()];
}

class _SchemaFlagProbeCommand extends Command<void> {
  _SchemaFlagProbeCommand(this.plugin) {
    argParser.addOption('name', help: 'Entity name');
  }

  final _SchemaFlagProbePlugin plugin;

  @override
  String get name => 'probe904';

  @override
  String get description => 'Hand-rolled probe: schema advertises use-mock.';

  @override
  Future<void> run() async => _noopSink('');
}

class _CamelCaseProbePlugin extends ZuraffaPlugin implements CliAwarePlugin {
  @override
  String get id => 'camel904';

  @override
  String get name => 'Camel 904 Probe Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => _CamelCaseProbeCommand(this);

  @override
  List<ZuraffaCapability> get capabilities => [_ProbeCapability()];
}

class _CamelCaseProbeCommand extends Command<void> {
  _CamelCaseProbeCommand(this.plugin) {
    argParser.addOption('name', help: 'Entity name');
  }

  final _CamelCaseProbePlugin plugin;

  @override
  String get name => 'camel904';

  @override
  String get description => 'Schema declares outputDir; parser lacks it.';

  @override
  Future<void> run() async => _noopSink('');
}

/// Shared probe capability: schema declares name (accepted) plus the two
/// #904-shaped properties (use-mock boolean, outputDir string) the probe
/// parsers do NOT accept.
class _ProbeCapability implements ZuraffaCapability {
  @override
  String get name => 'scaffold_thing';

  @override
  String get description => 'Probe capability mirroring the #904 drift.';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'use-mock': {
        'type': 'boolean',
        'description': 'Use mock datasources (the #904 seed property)',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Target directory (the camelCase #904 seed property)',
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'probe',
    pluginId: 'probe',
    capabilityName: name,
    args: args,
    changes: const [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: true, files: const []);
}

/// The help-text shape: the parser accepts the flag but the command's
/// usage surface hides it — help text and flags drift apart.
class _HiddenHelpProbePlugin extends ZuraffaPlugin implements CliAwarePlugin {
  @override
  String get id => 'hidden904';

  @override
  String get name => 'Hidden Help Probe Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => _HiddenHelpProbeCommand(this);

  @override
  List<ZuraffaCapability> get capabilities => [_HiddenHelpCapability()];
}

class _HiddenHelpProbeCommand extends Command<void> {
  _HiddenHelpProbeCommand(this.plugin) {
    argParser.addOption('secret-flag', help: 'Accepted but never advertised');
    argParser.addOption('name', help: 'Entity name');
  }

  final _HiddenHelpProbePlugin plugin;

  @override
  String get name => 'hidden904';

  @override
  String get description => 'Usage hides an accepted flag.';

  @override
  String get usage => 'usage: zfa hidden904 [--name <name>]';

  @override
  Future<void> run() async => _noopSink('');
}

class _HiddenHelpCapability implements ZuraffaCapability {
  @override
  String get name => 'scaffold_hidden';

  @override
  String get description => 'Capability served by the hidden-help probe.';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'secret-flag': {'type': 'string'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'hidden',
    pluginId: 'hidden904',
    capabilityName: name,
    args: args,
    changes: const [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(success: true, files: const []);
}

/// The #876 shape (spec 979's original probe): a PluginCommand that
/// registers a parent-level flag its run() never reads.
class _DeadFlagProbePlugin extends ZuraffaPlugin implements CliAwarePlugin {
  @override
  String get id => 'probe876';

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
  String get name => 'probe876';

  @override
  String get description => 'Probe command with one dead parent flag';

  @override
  Future<void> run() async {
    reportSubcommandUsage();
  }
}
