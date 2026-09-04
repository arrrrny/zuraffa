import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/datasource_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/datasource/capabilities/create_datasource_capability.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';

/// Spec #977 — one truth per flag: the capability input schema is
/// canonical, and the CLI flag defaults DERIVE from it.
///
/// Regression for the two-truths bug: `--local` used to advertise
/// `defaultsTo: true` in the command while the capability schema (and the
/// plugin config schema, and the capability's own `args['local'] ?? false`
/// resolution) said `default: false`.
void main() {
  late DataSourcePlugin plugin;
  late DataSourceCommand command;
  late CreateDataSourceCapability capability;

  setUp(() {
    plugin = DataSourcePlugin(
      outputDir: 'lib/src',
      options: const GeneratorOptions(),
    );
    command = DataSourceCommand(plugin);
    capability = plugin.capabilities
        .whereType<CreateDataSourceCapability>()
        .first;
  });

  CommandRunner<void> runner() =>
      CommandRunner<void>('zfa', 'test')..addCommand(command);

  test('CLI --local default equals capability schema default', () {
    final schemaDefault =
        capability.inputSchema['properties']['local']['default'] as bool;
    final cliDefault = command.argParser.options['local']!.defaultsTo as bool;

    expect(
      cliDefault,
      schemaDefault,
      reason: 'capability schema is canonical; the CLI flag derives from it',
    );
  });

  test('CLI --remote default equals capability schema default', () {
    final schemaDefault =
        capability.inputSchema['properties']['remote']['default'] as bool;
    final cliDefault = command.argParser.options['remote']!.defaultsTo as bool;

    expect(cliDefault, schemaDefault);
  });

  test('capability schema and plugin config schema agree on local', () {
    final capabilityDefault =
        capability.inputSchema['properties']['local']['default'] as bool;
    final pluginDefault =
        plugin.configSchema['properties']['local']['default'] as bool;

    expect(
      capabilityDefault,
      pluginDefault,
      reason: 'both schemas must state one truth',
    );
  });

  test('capability schema and plugin config schema agree on remote', () {
    final capabilityDefault =
        capability.inputSchema['properties']['remote']['default'] as bool;
    final pluginDefault =
        plugin.configSchema['properties']['remote']['default'] as bool;

    expect(capabilityDefault, pluginDefault);
  });

  test('CLI defaults survive a real parse of the command invocation', () {
    final root = runner().parse(['datasource']);
    final argResults = root.command!; // the `datasource` subcommand's args

    expect(
      argResults['local'],
      capability.inputSchema['properties']['local']['default'],
    );
    expect(
      argResults['remote'],
      capability.inputSchema['properties']['remote']['default'],
    );
  });
}
