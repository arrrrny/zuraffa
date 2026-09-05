import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';

/// Spec 979, order 3 — schema ≡ grammar parity for the provider plugin,
/// and the dead parent-flag purge.
///
/// The provider grammar is six plugin-specific knobs — `domain`, `params`,
/// `returns`, `type`, `data`, `init`. Before this spec, all six were ALSO
/// registered on the PARENT `zfa provider` command, whose run() only prints
/// subcommand usage (bug #856): every parent-level value was parsed,
/// advertised by `--help`, and never read — the #876 "flags that lie"
/// family. The purge removes them all; the live surface is the
/// `zfa provider create` subcommand grammar, synthesized by
/// [CapabilityCommand] from the create capability's inputSchema.
///
/// Parity (mini treaty, both directions):
///   * every plugin-specific knob appears in `ProviderPlugin.configSchema`
///     (what JSON agents and `zfa make` see) AND in
///     `CreateProviderCapability.inputSchema` (what synthesizes the
///     subcommand flags);
///   * the parent command registers ZERO plugin-specific flags.
void main() {
  ProviderPlugin plugin() => ProviderPlugin(outputDir: 'lib/src');

  /// The provider-specific knobs (the grammar contract).
  const grammarKnobs = {'domain', 'params', 'returns', 'type', 'data', 'init'};

  /// Flags every PluginCommand carries (shared machinery, not the provider
  /// contract) plus package:args' automatic --help.
  const baseFlags = {'output', 'dry-run', 'force', 'verbose', 'revert', 'help'};

  test('grep-proof: the parent zfa provider command registers ZERO '
      'plugin-specific flags (dead-flag purge, #876 family)', () {
    final command = plugin().createCommand();
    final pluginSpecific = command.argParser.options.keys
        .where((f) => !baseFlags.contains(f))
        .toSet();

    expect(
      pluginSpecific,
      isEmpty,
      reason:
          'zfa provider --help must not advertise flags run() never reads '
          '(dead: $pluginSpecific). The live surface is '
          '`zfa provider create --<knob>`, synthesized from the create '
          'capability inputSchema (issue #979 order 3).',
    );
  });

  test('the create subcommand grammar synthesizes every knob '
      '(inputSchema parity — --init used to be a parse error)', () {
    final command = plugin().createCommand();
    final create = command.subcommands['create'];

    expect(create, isNotNull, reason: 'zfa provider create must exist');
    final options = create!.argParser.options.keys.toSet();

    for (final knob in grammarKnobs) {
      expect(
        options.contains(knob),
        isTrue,
        reason:
            '`zfa provider create --$knob` must parse: CapabilityCommand '
            'synthesizes subcommand flags from the create capability\'s '
            'inputSchema (issue #979: --init was unreachable)',
      );
    }

    // Schema round-trip: the create inputSchema declares the same knobs.
    final capability = plugin().capabilities.firstWhere(
      (c) => c.name == 'create',
    );
    final inputProps =
        capability.inputSchema['properties'] as Map<String, dynamic>;
    for (final knob in grammarKnobs) {
      expect(inputProps.containsKey(knob), isTrue);
    }
  });

  test('type knob: the CLI enum and the schema enum agree '
      '(sync/stream/completable/usecase)', () {
    const allowed = ['sync', 'stream', 'completable', 'usecase'];

    final command = plugin().createCommand();
    final create = command.subcommands['create']!;
    final typeOption = create.argParser.options['type'];

    expect(typeOption, isNotNull);
    expect(typeOption!.allowed, equals(allowed));

    final capability = plugin().capabilities.firstWhere(
      (c) => c.name == 'create',
    );
    final inputProps =
        capability.inputSchema['properties'] as Map<String, dynamic>;
    expect(
      (inputProps['type'] as Map<String, dynamic>)['enum'],
      equals(allowed),
      reason: 'JSON agents must see the same allowed values as the CLI',
    );
  });

  test('mini treaty, both directions: configSchema knobs ≡ create inputSchema '
      'knobs (minus the machinery slots)', () {
    final configProps =
        plugin().configSchema['properties'] as Map<String, dynamic>;
    final schemaProps = configProps.keys.toSet();

    final capability = plugin().capabilities.firstWhere(
      (c) => c.name == 'create',
    );
    final inputProps =
        (capability.inputSchema['properties'] as Map<String, dynamic>).keys
            .toSet();
    // Machinery the create capability declares that is not a grammar knob.
    const machinery = {'name', 'dryRun', 'force', 'verbose'};

    final schemaOnly = inputProps
        .difference(machinery)
        .difference(grammarKnobs);
    expect(
      schemaOnly,
      isEmpty,
      reason:
          'create inputSchema advertises knobs outside the treaty: '
          '$schemaOnly',
    );

    final grammarOnly = grammarKnobs.difference(schemaProps);
    expect(
      grammarOnly,
      isEmpty,
      reason:
          'grammar knobs missing from create inputSchema: '
          '$grammarOnly',
    );

    // configSchema must advertise every grammar knob too (JSON agents and
    // `zfa make` synthesize their contract from it).
    for (final knob in grammarKnobs) {
      expect(
        schemaProps.contains(knob),
        isTrue,
        reason: 'configSchema must advertise `$knob` (schema drift)',
      );
    }
  });

  test('--init flows through create end-to-end: the generated provider '
      'carries the init/dispose lifecycle members', () async {
    final dir = await Directory.systemTemp.createTemp(
      'zfa_provider_init_flow_',
    );
    try {
      final outputDir = '${dir.path}/lib/src';
      final p = ProviderPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final capability = p.capabilities.firstWhere((c) => c.name == 'create');

      // The provider implements a service interface — scaffold it first.
      final services = Directory('$outputDir/domain/services');
      await services.create(recursive: true);
      await File('${services.path}/billing_service.dart').writeAsString('''
import 'package:zuraffa/zuraffa.dart';

abstract class BillingService {}
''');

      final result = await capability.execute({
        'name': 'Billing',
        'init': true,
      });

      expect(result.success, isTrue);
      final content = File(result.files.first).readAsStringSync();
      expect(content, contains('class BillingProvider'));
      expect(content, contains('Stream<bool> get isInitialized'));
      expect(content, contains('Future<void> initialize'));
      expect(content, contains('Future<void> dispose'));
    } finally {
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  });
}
