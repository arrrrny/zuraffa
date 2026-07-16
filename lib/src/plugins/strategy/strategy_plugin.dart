import 'package:args/command_runner.dart';

import '../../commands/strategy_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/strategy_builder.dart';
import 'capabilities/create_strategy_capability.dart';

/// Generates FetchStrategy skeletons for pluggable data-fetching pipelines.
///
/// A `StrategyPlugin` run produces:
///
/// - An abstract domain strategy base extending `FetchStrategy<Input, Output>`
/// - One concrete variant per `--strategies` name with `canHandle` + `fetchOne` stubs
/// - A `StrategySelector` that wires all variants and selects the first applicable
///
/// Files land in `data/providers/{domain}/strategies/` — the data layer only.
/// The abstract `FetchStrategy<I, O>` from Zuraffa core is the only domain contract.
///
/// ## Usage
///
/// ```bash
/// zfa strategy UrlListing --strategies=scraper,ai --params=UrlSpark --returns=Listing --domain=listing
/// ```
///
/// ## runAfter
///
/// Runs after `provider` because the generated files live inside the provider folder.
class StrategyPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final StrategyBuilder strategyBuilder;

  StrategyPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) : strategyBuilder = StrategyBuilder(
         outputDir: outputDir,
         options: options,
       );

  @override
  List<ZuraffaCapability> get capabilities => [CreateStrategyCapability(this)];

  @override
  Command createCommand() => StrategyCommand(this);

  @override
  String get id => 'strategy';

  @override
  String get name => 'Strategy Plugin';

  @override
  String get version => '1.0.0';

  @override
  List<String> get runAfter => ['provider'];

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'strategies': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Variant names to generate (e.g. [scraper, ai])',
      },
      'params': {
        'type': 'string',
        'description': 'Input type for FetchStrategy<Input, Output>',
      },
      'returns': {
        'type': 'string',
        'description': 'Output type for FetchStrategy<Input, Output>',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final strategiesRaw = context.get<String>('strategies') ?? '';
    final strategyNames = strategiesRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      enableStrategy: true,
      strategyNames: strategyNames,
      paramsType: context.get<String>('params'),
      returnsType: context.get<String>('returns'),
      domain: context.get<String>('domain'),
    );

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.enableStrategy && !config.revert) {
      return [];
    }
    return strategyBuilder.generate(config);
  }
}
