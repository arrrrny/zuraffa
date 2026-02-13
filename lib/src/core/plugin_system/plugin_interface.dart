import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'plugin_lifecycle.dart';

abstract class ZuraffaPlugin {
  String get id;
  String get name;
  String get version;
  int get order => 0;

  Future<ValidationResult> validate(GeneratorConfig config) async {
    return ValidationResult.success();
  }

  Future<void> beforeGenerate(GeneratorConfig config) async {}

  Future<void> afterGenerate(GeneratorConfig config) async {}

  Future<void> onError(
    GeneratorConfig config,
    Object error,
    StackTrace stackTrace,
  ) async {}
}

abstract class FileGeneratorPlugin extends ZuraffaPlugin {
  Future<List<GeneratedFile>> generate(GeneratorConfig config);
}
