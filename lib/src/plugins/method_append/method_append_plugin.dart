import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/method_append_builder.dart';
import 'capabilities/append_method_capability.dart';

/// Manages appending methods to existing classes.
///
/// Provides capabilities to add new methods to repositories, services,
/// and data sources without overwriting existing files.
///
/// Example:
/// ```dart
/// final plugin = MethodAppendPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final result = await plugin.appendMethod(GeneratorConfig(name: 'Product'));
/// ```
class MethodAppendPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final MethodAppendBuilder methodAppendBuilder;

  MethodAppendPlugin({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
  }) : options = options.copyWith(
         dryRun: dryRun ?? options.dryRun,
         force: force ?? options.force,
         verbose: verbose ?? options.verbose,
       ) {
    methodAppendBuilder = MethodAppendBuilder(
      outputDir: outputDir,
      options: this.options,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [AppendMethodCapability(this)];

  @override
  String get id => 'method_append';

  @override
  String get name => 'Method Append Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose) {
      final delegator = MethodAppendPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
        ),
      );
      return delegator.generate(config);
    }

    if (config.appendToExisting) {
      final result = await appendMethod(config);
      return result.updatedFiles;
    }
    return [];
  }

  Future<MethodAppendResult> appendMethod(GeneratorConfig config) async {
    return methodAppendBuilder.appendMethod(config);
  }
}
