import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/patterns/common_patterns.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/constants/known_types.dart';
import '../../../core/plugin_system/discovery_engine.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_utils.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../core/dependencies/dependency_wirer.dart';

part 'test_builder_custom.dart';
part 'test_builder_entity.dart';
part 'test_builder_helpers.dart';
part 'test_builder_orchestrator.dart';
part 'test_builder_polymorphic.dart';

/// Generates test files for use cases and entity workflows.
class TestBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final DiscoveryEngine discovery;
  final FileSystem fileSystem;

  // #354: cached Flutter-vs-pure-Dart detection for the test framework +
  // zuraffa core imports. `null` = not yet resolved. Computed lazily by
  // `_isFlutterProject` in TestBuilderHelpers. Reset by re-creating the
  // TestBuilder (each TestBuilder instance targets one projectRoot).
  bool? _cachedIsFlutterProject;

  /// Creates a [TestBuilder].
  TestBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       fileSystem = fileSystem ?? FileSystem.create(),
       discovery =
           discovery ??
           DiscoveryEngine(
             projectRoot: outputDir,
             fileSystem: fileSystem ?? FileSystem.create(),
           );
}
