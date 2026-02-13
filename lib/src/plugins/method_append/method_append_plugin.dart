import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/method_append_builder.dart';

class MethodAppendPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  late final MethodAppendBuilder methodAppendBuilder;

  MethodAppendPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  }) {
    methodAppendBuilder = MethodAppendBuilder(
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
  }

  @override
  String get id => 'method_append';

  @override
  String get name => 'Method Append Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    return [];
  }

  Future<MethodAppendResult> appendMethod(GeneratorConfig config) async {
    return methodAppendBuilder.appendMethod(config);
  }
}
