import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/generated_file.dart';
import '../utils/string_utils.dart';

/// Locates presentation layer files by convention in a Zuraffa v5 project.
class RegisterFileLocator {
  final String outputDir;

  const RegisterFileLocator({required this.outputDir});

  /// Finds the presenter file path for an entity in a domain.
  ///
  /// Returns `lib/src/presentation/pages/{domain}/{entity_snake}_presenter.dart`
  String findPresenterFile(String entity, String domain) {
    final entitySnake = StringUtils.camelToSnake(entity);
    return path.join(
      outputDir,
      'presentation',
      'pages',
      domain,
      '${entitySnake}_presenter.dart',
    );
  }

  /// Finds the controller file path for an entity in a domain.
  ///
  /// Returns `lib/src/presentation/pages/{domain}/{entity_snake}_controller.dart`
  String findControllerFile(String entity, String domain) {
    final entitySnake = StringUtils.camelToSnake(entity);
    return path.join(
      outputDir,
      'presentation',
      'pages',
      domain,
      '${entitySnake}_controller.dart',
    );
  }

  /// Finds the state file path for an entity in a domain.
  ///
  /// Returns `lib/src/presentation/pages/{domain}/{entity_snake}_state.dart`
  String findStateFile(String entity, String domain) {
    final entitySnake = StringUtils.camelToSnake(entity);
    return path.join(
      outputDir,
      'presentation',
      'pages',
      domain,
      '${entitySnake}_state.dart',
    );
  }

  /// Scans the use cases directory to find a use case file matching the target name.
  ///
  /// Returns the content analysis of the first matching use case, or `null`
  /// if no matching use case is found.
  UseCaseFileInfo? findUseCase(String target) {
    final usecasesDir = Directory(path.join(outputDir, 'domain', 'usecases'));
    if (!usecasesDir.existsSync()) return null;

    final targetSnake = StringUtils.camelToSnake(target);
    for (final domainDir in usecasesDir.listSync().whereType<Directory>()) {
      final domainName = path.basename(domainDir.path);
      // Try multiple naming patterns
      for (final suffix in ['', '_usecase', '_use_case']) {
        final filePath = path.join(domainDir.path, '$targetSnake$suffix.dart');
        final file = File(filePath);
        if (file.existsSync()) {
          return UseCaseFileInfo(filePath: filePath, domain: domainName);
        }
      }
    }
    return null;
  }

  /// Infers the domain from a use case name by scanning the use cases directory.
  ///
  /// Returns the domain directory name, or `null` if not found.
  String? inferDomain(String target) {
    final info = findUseCase(target);
    return info?.domain;
  }

  /// Checks if the presenter file exists.
  bool presenterExists(String entity, String domain) {
    return File(findPresenterFile(entity, domain)).existsSync();
  }

  /// Checks if the controller file exists.
  bool controllerExists(String entity, String domain) {
    return File(findControllerFile(entity, domain)).existsSync();
  }

  /// Checks if the state file exists.
  bool stateExists(String entity, String domain) {
    return File(findStateFile(entity, domain)).existsSync();
  }
}

/// Information about a found use case file.
class UseCaseFileInfo {
  final String filePath;
  final String domain;

  const UseCaseFileInfo({required this.filePath, required this.domain});
}

/// Result of a register operation.
class RegisterResult {
  final bool success;
  final List<GeneratedFile> files;
  final String? message;

  const RegisterResult({
    required this.success,
    required this.files,
    this.message,
  });
}

/// Inserts a statement into the constructor body of a class.
///
/// Finds the first constructor in the source and adds [statement]
/// before the closing '}' of the constructor body.
String insertIntoConstructorBody(
  String source,
  String className,
  String statement,
) {
  final classPattern = 'class $className';
  final classIndex = source.indexOf(classPattern);
  if (classIndex == -1) return source;

  // Find constructor - look for the pattern `ClassName() {` or `ClassName(`
  final afterClass = source.substring(classIndex);
  final constructorStart = _findConstructorBodyStart(afterClass, className);
  if (constructorStart == -1) return source;

  final globalStart = classIndex + constructorStart;
  final bodyStart = source.indexOf('{', globalStart);
  if (bodyStart == -1) return source;

  // Find the matching closing brace
  final bodyEnd = _findMatchingClose(source, bodyStart);
  if (bodyEnd == -1) return source;

  // Check if statement already exists in constructor body
  final bodyContent = source.substring(bodyStart + 1, bodyEnd);
  if (bodyContent.contains(statement.trim())) return source;
  final indent = _getIndentation(source, bodyEnd - 1);
  final newStatement = '$indent$statement\n$indent';

  return source.substring(0, bodyEnd) +
      newStatement +
      source.substring(bodyEnd);
}

int _findConstructorBodyStart(String source, String className) {
  final pattern = '$className(';
  return source.indexOf(pattern);
}

int _findMatchingClose(String source, int openPos) {
  var depth = 0;
  for (var i = openPos; i < source.length; i++) {
    if (source[i] == '{') {
      depth++;
    } else if (source[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

String _getIndentation(String source, int pos) {
  final lineStart = source.lastIndexOf('\n', pos);
  if (lineStart == -1) return '  ';
  final line = source.substring(lineStart + 1, pos + 1);
  final indent = RegExp(r'^(\s*)').firstMatch(line)?.group(1) ?? '';
  return indent;
}
