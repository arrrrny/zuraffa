import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

/// Issue #978, order 2 — schema ≡ grammar parity for the service plugin.
///
/// The service grammar is four plugin-specific knobs — `params`, `returns`,
/// `type`, `init` — declared on `ServiceCommand`. Every one of them must
/// also be advertised in:
///   - `ServicePlugin.configSchema` — what JSON agents and `zfa make` see
///     (make synthesizes flags AND merges context data from these
///     properties), and
///   - `CreateServiceCapability.inputSchema` — what synthesizes the
///     `zfa service create` subcommand's flags (a knob missing there is
///     unreachable from the CLI: `--init` used to be a parse error).
///
/// And vice versa: no schema property may exist that the CLI grammar does
/// not offer (drift in the other direction). This is the mini treaty check
/// for this plugin.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_service_treaty_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ServicePlugin plugin() => ServicePlugin(outputDir: outputDir);

  /// The plugin-specific knobs of the service grammar. The base flags every
  /// PluginCommand carries (output/dry-run/force/verbose/revert) and the
  /// capability-machinery flags (json/name) are shared machinery, not the
  /// service contract.
  const grammarKnobs = {'params', 'returns', 'type', 'init'};

  test(
    'configSchema advertises every grammar knob (params/returns/type/init)',
    () {
      final props = plugin().configSchema['properties'] as Map<String, dynamic>;

      for (final knob in grammarKnobs) {
        expect(
          props.containsKey(knob),
          isTrue,
          reason:
              'configSchema must advertise `$knob` — JSON agents and zfa '
              'make synthesize their contract from configSchema (issue '
              '#978 schema drift)',
        );
      }
      // The historical `service` name-slot stays advertised.
      expect(props.containsKey('service'), isTrue);
    },
  );

  test(
    'the create subcommand grammar synthesizes --init (inputSchema parity)',
    () {
      final command = plugin().createCommand();
      final create = command.subcommands['create'];

      expect(create, isNotNull, reason: 'zfa service create must exist');
      final options = create!.argParser.options.keys.toSet();

      for (final knob in grammarKnobs) {
        expect(
          options.contains(knob),
          isTrue,
          reason:
              '`zfa service create --$knob` must parse: CapabilityCommand '
              'synthesizes subcommand flags from the create capability\'s '
              'inputSchema (issue #978: --init was unreachable)',
        );
      }
      // Schema grammar round-trip: the create inputSchema declares the same
      // knobs (this is what the flag synthesis reads).
      final capability = plugin().capabilities.firstWhere(
        (c) => c.name == 'create',
      );
      final inputProps =
          capability.inputSchema['properties'] as Map<String, dynamic>;
      for (final knob in grammarKnobs) {
        expect(inputProps.containsKey(knob), isTrue);
      }
    },
  );

  test('type knob: the CLI enum and the schema enum agree '
      '(sync/stream/completable/usecase)', () {
    const cliAllowed = ['sync', 'stream', 'completable', 'usecase'];

    final command = plugin().createCommand();
    final create = command.subcommands['create']!;
    final typeOption = create.argParser.options['type'];

    expect(typeOption, isNotNull);
    expect(typeOption!.allowed, equals(cliAllowed));

    final capability = plugin().capabilities.firstWhere(
      (c) => c.name == 'create',
    );
    final inputProps =
        capability.inputSchema['properties'] as Map<String, dynamic>;
    expect(
      (inputProps['type'] as Map<String, dynamic>)['enum'],
      equals(cliAllowed),
      reason: 'JSON agents must see the same allowed values as the CLI',
    );
  });

  test('mini treaty, both directions: every plugin-specific ServiceCommand '
      'flag is in configSchema, and every configSchema property (other than '
      'the service name-slot) is a ServiceCommand flag', () {
    // Grammar side: the plugin-specific flags declared on the service
    // command itself (base flags + package:args' automatic --help
    // filtered out).
    const baseFlags = {
      'output',
      'dry-run',
      'force',
      'verbose',
      'revert',
      'help',
    };
    final command = plugin().createCommand();
    final commandFlags = command.argParser.options.keys
        .where((f) => !baseFlags.contains(f))
        .toSet();

    // Schema side.
    final configProps =
        plugin().configSchema['properties'] as Map<String, dynamic>;
    final schemaProps = configProps.keys.toSet();

    // configSchema ∖ {service} ⊆ command grammar — schema may not
    // advertise flags the CLI cannot parse.
    final schemaOnly = schemaProps.difference({...commandFlags, 'service'});
    expect(
      schemaOnly,
      isEmpty,
      reason:
          'configSchema advertises knobs the service command grammar does '
          'not offer: $schemaOnly (grammar drift)',
    );

    // command grammar ⊆ configSchema — every CLI knob must be visible to
    // JSON agents / make.
    final grammarOnly = commandFlags.difference(schemaProps);
    expect(
      grammarOnly,
      isEmpty,
      reason:
          'the service command grammar offers knobs configSchema does not '
          'advertise: $grammarOnly (issue #978 schema drift)',
    );
  });

  test('--init flows through create end-to-end: the generated interface '
      'carries the init/dispose lifecycle members', () async {
    final p = ServicePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final capability = p.capabilities.firstWhere((c) => c.name == 'create');

    final result = await capability.execute({'name': 'Billing', 'init': true});

    expect(result.success, isTrue);
    expect(result.files, hasLength(1));
    final content = File(result.files.first).readAsStringSync();
    expect(content, contains('abstract class BillingService'));
    expect(content, contains('Stream<bool> get isInitialized'));
    expect(content, contains('Future<void> initialize'));
    expect(content, contains('Future<void> dispose'));
  });
}
