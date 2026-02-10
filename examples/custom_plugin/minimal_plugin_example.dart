import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/utils/file_utils.dart';

class MinimalPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  MinimalPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
  });

  @override
  String get id => 'minimal_example';

  @override
  String get name => 'Minimal Plugin Example';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final filePath = path.join(outputDir, 'custom_plugin', 'minimal_output.txt');
    final file = await FileUtils.writeFile(
      filePath,
      'Minimal plugin output for ${config.name}',
      'custom_plugin',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
    return [file];
  }
}
