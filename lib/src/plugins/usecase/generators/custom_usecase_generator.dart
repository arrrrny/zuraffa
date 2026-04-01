import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../builders/usecase_class_builder.dart';

part 'custom_usecase_generator_append.dart';
part 'custom_usecase_generator_core.dart';
part 'custom_usecase_generator_generate.dart';
part 'custom_usecase_generator_methods.dart';
part 'custom_usecase_generator_orchestrator.dart';
part 'custom_usecase_generator_polymorphic.dart';

/// Generates custom use cases for the domain layer.
class CustomUseCaseGenerator {
  final String outputDir;
  final GeneratorOptions options;
  final UseCaseClassBuilder classBuilder;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  CustomUseCaseGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const UseCaseClassBuilder(),
    this.appendExecutor = const AppendExecutor(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create(root: outputDir);
}
