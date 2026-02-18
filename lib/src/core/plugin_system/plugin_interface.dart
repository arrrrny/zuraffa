import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capability.dart';
import 'plugin_lifecycle.dart';

abstract class ZuraffaPlugin {
  String get id;
  String get name;
  String get version;
  int get order => 0;

  /// Returns the list of capabilities exposed by this plugin.
  List<ZuraffaCapability> get capabilities => [];

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

  // New atomic action methods
  // These should be implemented by plugins that support atomic actions
  // If not implemented, they should throw or return empty
  Future<List<GeneratedFile>> create(GeneratorConfig config) =>
      generate(config);
  Future<List<GeneratedFile>> delete(GeneratorConfig config) =>
      generate(config);
  Future<List<GeneratedFile>> add(GeneratorConfig config) => generate(config);
  Future<List<GeneratedFile>> remove(GeneratorConfig config) =>
      generate(config);
}
