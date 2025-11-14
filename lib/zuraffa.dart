/// Zuraffa: AI-First Clean Architecture State Management for Flutter
///
/// Generate production-ready code from JSON with TDD, 100% test coverage,
/// and zero boilerplate.
library zuraffa;

// Phase 1: JSON parsing and entity generation
export 'src/json_parser.dart';
export 'src/entity_generator.dart';
export 'src/build_runner.dart';
export 'src/file_writer.dart';
export 'src/generator.dart';
export 'src/build_yaml_generator.dart';
export 'src/exceptions.dart';

// Phase 2: Full-stack generation
export 'src/result.dart';
export 'src/failures.dart';
export 'src/usecase.dart';
export 'src/usecase_generator.dart';
export 'src/datasource_generator.dart';
export 'src/repository_generator.dart';
export 'src/fullstack_generator.dart';
