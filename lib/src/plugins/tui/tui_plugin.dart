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
import 'generator/capabilities/create_tui_screens_capability.dart';
import 'generator/tui_screen_generator.dart';

/// The built-in Zuraffa TUI plugin.
///
/// Registers the TUI screen generation capability with the `zfa make`
/// pipeline so `--with=tui` emits list/detail TUI screens wired to an
/// entity's existing use cases (FR-011).
///
/// Naming follows the existing repo convention (`McpPlugin`, `ViewPlugin`,
/// `RoutePlugin` — short domain + `Plugin` suffix). The full type alias
/// `ZuraffaTuiPlugin` is also exported for callers that prefer the
/// qualified name.
class TuiPlugin extends ZuraffaPlugin {
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
}

/// Qualified alias for [TuiPlugin] — kept for callers that prefer the
/// `ZuraffaTuiPlugin` form in docs / sample code.
typedef ZuraffaTuiPlugin = TuiPlugin;
