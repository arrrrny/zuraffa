import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/constants/known_types.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

part 'test_builder_custom.dart';
part 'test_builder_entity.dart';
part 'test_builder_helpers.dart';
part 'test_builder_orchestrator.dart';
part 'test_builder_polymorphic.dart';

/// Generates test files for use cases and entity workflows.
///
/// Emits test suites for entity, custom, orchestrator, and polymorphic use cases
/// based on the configured generation options.
///
/// Example:
/// ```dart
/// final builder = TestBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// ```
class TestBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;

  /// Creates a [TestBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param specLibrary Optional spec library override.
  TestBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();
}
