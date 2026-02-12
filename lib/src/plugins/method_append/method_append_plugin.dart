import '../../core/plugin_system/plugin_interface.dart';
import '../../generator/method_appender.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

class MethodAppendPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool verbose;

  MethodAppendPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.verbose,
  });

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

  Future<AppendResult> appendMethod(
    GeneratorConfig config,
  ) async {
    final appender = MethodAppender(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      verbose: verbose,
    );
    return appender.appendMethod();
  }
}
