/// Built-in Zuraffa TUI plugin — registers the TUI capability with the
/// `zfa make` generator pipeline (FR-010).
///
/// Apps discover the TUI plugin through the standard `ZuraffaPlugin`
/// extension point; no separate install is required. The plugin contributes
/// one capability:
///
/// * [CreateTuiScreensCapability] — invoked by `zfa make --with=tui` to emit
///   list/detail TUI screens wired to an entity's existing use cases
///   (FR-011, SC-005).
///
/// The plugin is pure-Dart (no `package:flutter` dependency, FR-012). It
/// lives in the core `zuraffa` package so any Zuraffa app — Flutter or
/// pure-Dart — can adopt it.
library;

import '../../core/generator_options.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/entity_analyzer.dart';
import '../../utils/file_utils.dart';
import 'generator/capabilities/create_tui_screens_capability.dart';
import 'generator/tui_screen_generator.dart';

/// The built-in Zuraffa TUI plugin.
///
/// Issue #1149 (kill list — tui fate): the plugin is wired as a
/// [FileGeneratorPlugin] so `zfa make X --with=tui` actually runs in the
/// make pipeline (previously the plugin was not a FileGeneratorPlugin and
/// the pipeline silently skipped it — a lying "No files generated.").
/// Entity fields are derived from the real entity source via
/// [EntityAnalyzer]; use cases are derived from the run's `--methods`;
/// both screens are persisted through the transaction-aware
/// [FileUtils.writeFile].
///
/// Registers the TUI screen generation capability with the `zfa make`
/// pipeline so `--with=tui` emits list/detail TUI screens wired to an
/// entity's existing use cases (FR-011).
///
/// Naming follows the existing repo convention (`McpPlugin`, `ViewPlugin`,
/// `RoutePlugin` — short domain + `Plugin` suffix). The full type alias
/// `ZuraffaTuiPlugin` is also exported for callers that prefer the
/// qualified name.
class TuiPlugin extends FileGeneratorPlugin {
  /// Constructs the TUI plugin with an optional output directory and
  /// generator options (mirrors the existing plugin constructor pattern).
  TuiPlugin({
    this.outputDir = 'lib/src',
    this.options = const GeneratorOptions(),
    TuiScreenGenerator? generator,
  }) : _generator = generator ?? TuiScreenGenerator();

  final String outputDir;
  final GeneratorOptions options;
  final TuiScreenGenerator _generator;

  @override
  String get id => 'tui';

  @override
  String get name => 'TUI';

  @override
  String get version => '0.1.0';

  @override
  List<String> get dependsOn => const ['usecase', 'repository'];

  @override
  List<String> get runAfter => const ['usecase'];

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateTuiScreensCapability(generator: _generator, outputDir: outputDir),
  ];

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      methods: context.data['methods']?.cast<String>().toList() ?? const [],
    );
    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entityFields = EntityAnalyzer.analyzeEntity(
      entityName,
      config.outputDir,
    );
    final fields = [
      for (final entry in entityFields.entries)
        TuiFieldSpec(name: entry.key, type: entry.value),
    ];

    final methods = config.methods.isEmpty
        ? const ['get', 'getList']
        : config.methods;
    final useCases = [
      for (final method in methods)
        TuiUseCaseSpec(
          name: method,
          returnsType: _returnsTypeFor(entityName, method),
          isStream: _isStreamFor(method),
          paramsType: method == 'get' ? 'String' : null,
        ),
    ];

    final capability = CreateTuiScreensCapability(
      generator: _generator,
      outputDir: config.outputDir,
    );
    final files = capability.generateFiles({
      'name': entityName,
      'fields': [
        for (final f in fields) {'name': f.name, 'type': f.type},
      ],
      'useCases': [
        for (final u in useCases)
          {
            'name': u.name,
            'returnsType': u.returnsType,
            'isStream': u.isStream,
            if (u.paramsType != null) 'paramsType': u.paramsType,
          },
      ],
    });

    final persisted = <GeneratedFile>[];
    for (final file in files) {
      persisted.add(
        await FileUtils.writeFile(
          file.path,
          file.content!,
          file.type,
          force: config.force,
          dryRun: config.dryRun,
          verbose: config.verbose,
          revert: config.revert,
        ),
      );
    }
    return persisted;
  }

  /// Mirrors the usecase plugin's return-type semantics so the generated
  /// screens reference types the pipeline actually emits.
  String _returnsTypeFor(String entityName, String method) => switch (method) {
    'getList' => 'List<$entityName>',
    'watchList' => 'List<$entityName>',
    'delete' => 'bool',
    'get' || 'watch' || 'create' || 'update' => entityName,
    _ => entityName,
  };

  bool _isStreamFor(String method) =>
      method == 'getList' || method == 'watch' || method == 'watchList';
}

/// Qualified alias for [TuiPlugin] — kept for callers that prefer the
/// `ZuraffaTuiPlugin` form in docs / sample code.
typedef ZuraffaTuiPlugin = TuiPlugin;
