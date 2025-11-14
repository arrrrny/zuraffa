/// Custom exceptions for Zuraffa code generation
///
/// Provides clear error messages with helpful guidance

/// Base exception for all Zuraffa errors
class ZuraffaException implements Exception {
  final String message;
  final String? hint;
  final dynamic cause;

  ZuraffaException(this.message, {this.hint, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('❌ Zuraffa Error: $message');
    if (hint != null) {
      buffer.writeln('💡 Hint: $hint');
    }
    if (cause != null) {
      buffer.writeln('📋 Details: $cause');
    }
    return buffer.toString();
  }
}

/// Thrown when JSON parsing fails
class JsonParseException extends ZuraffaException {
  JsonParseException(String message, {String? hint, dynamic cause})
      : super(message, hint: hint, cause: cause);

  factory JsonParseException.invalidJson(dynamic cause) {
    return JsonParseException(
      'Invalid JSON format',
      hint: 'Check your JSON file for syntax errors (missing commas, brackets, etc.)',
      cause: cause,
    );
  }

  factory JsonParseException.emptyJson() {
    return JsonParseException(
      'JSON is empty or null',
      hint: 'Provide a valid JSON object with at least one field',
    );
  }

  factory JsonParseException.notAnObject(dynamic json) {
    return JsonParseException(
      'JSON must be an object (map), got ${json.runtimeType}',
      hint: 'Wrap your JSON in curly braces: { "field": "value" }',
    );
  }
}

/// Thrown when file operations fail
class FileException extends ZuraffaException {
  FileException(String message, {String? hint, dynamic cause})
      : super(message, hint: hint, cause: cause);

  factory FileException.notFound(String path) {
    return FileException(
      'File not found: $path',
      hint: 'Check the file path and ensure the file exists',
    );
  }

  factory FileException.cannotRead(String path, dynamic cause) {
    return FileException(
      'Cannot read file: $path',
      hint: 'Check file permissions',
      cause: cause,
    );
  }

  factory FileException.cannotWrite(String path, dynamic cause) {
    return FileException(
      'Cannot write file: $path',
      hint: 'Check directory permissions and disk space',
      cause: cause,
    );
  }
}

/// Thrown when entity generation fails
class EntityGenerationException extends ZuraffaException {
  EntityGenerationException(String message, {String? hint, dynamic cause})
      : super(message, hint: hint, cause: cause);

  factory EntityGenerationException.noEntityName() {
    return EntityGenerationException(
      'Entity name is required',
      hint: 'Provide --name flag or a positional argument',
    );
  }

  factory EntityGenerationException.invalidEntityName(String name) {
    return EntityGenerationException(
      'Invalid entity name: $name',
      hint: 'Entity names must be valid Dart class names (PascalCase, start with letter)',
    );
  }
}

/// Thrown when build_runner fails
class BuildRunnerException extends ZuraffaException {
  BuildRunnerException(String message, {String? hint, dynamic cause})
      : super(message, hint: hint, cause: cause);

  factory BuildRunnerException.executionFailed(int exitCode, String stderr) {
    return BuildRunnerException(
      'build_runner failed with exit code $exitCode',
      hint: 'Check the error output below and ensure you have '
          'build_runner and zikzak_morphy in dev_dependencies',
      cause: stderr,
    );
  }

  factory BuildRunnerException.notInstalled() {
    return BuildRunnerException(
      'build_runner is not installed',
      hint: 'Add to pubspec.yaml dev_dependencies:\n'
          '  build_runner: ^2.4.0\n'
          '  zikzak_morphy: ^2.8.3',
    );
  }
}

/// Thrown when dependencies are missing
class DependencyException extends ZuraffaException {
  DependencyException(String message, {String? hint, dynamic cause})
      : super(message, hint: hint, cause: cause);

  factory DependencyException.morphyNotFound() {
    return DependencyException(
      'zikzak_morphy package not found',
      hint: 'Add to pubspec.yaml dependencies:\n'
          '  zikzak_morphy: ^2.8.3\n\n'
          'Then run: dart pub get',
    );
  }

  factory DependencyException.pubGetNeeded() {
    return DependencyException(
      'Dependencies not installed',
      hint: 'Run: dart pub get',
    );
  }
}
