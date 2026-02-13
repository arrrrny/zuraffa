import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';

class AstParseResult {
  final CompilationUnit? unit;
  final List<Diagnostic> errors;

  const AstParseResult({required this.unit, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
}

class FileParser {
  const FileParser();

  Future<AstParseResult> parseFile(String path) async {
    final source = await File(path).readAsString();
    return parseSource(source, path: path);
  }

  AstParseResult parseSource(String source, {String path = 'input.dart'}) {
    try {
      final result = parseString(
        content: source,
        path: path,
        throwIfDiagnostics: false,
      );
      return AstParseResult(
        unit: result.unit,
        errors: result.errors.cast<Diagnostic>(),
      );
    } catch (_) {
      return const AstParseResult(unit: null, errors: []);
    }
  }
}
