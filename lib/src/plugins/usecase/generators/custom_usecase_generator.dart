import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/constants/known_types.dart';
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

class CustomUseCaseGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final UseCaseClassBuilder classBuilder;
  final AppendExecutor appendExecutor;

  CustomUseCaseGenerator({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    UseCaseClassBuilder? classBuilder,
    AppendExecutor? appendExecutor,
  }) : classBuilder = classBuilder ?? const UseCaseClassBuilder(),
       appendExecutor = appendExecutor ?? AppendExecutor();
}
