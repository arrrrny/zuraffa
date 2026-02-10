import 'package:analyzer/dart/ast/ast.dart';

import '../ast_helper.dart';
import 'append_strategy.dart';

class ImportAppendStrategy implements AppendStrategy {
  final AstHelper helper;

  const ImportAppendStrategy({this.helper = const AstHelper()});

  @override
  bool canHandle(AppendRequest request) {
    return request.target == AppendTarget.importDirective &&
        request.importPath != null;
  }

  @override
  AppendResult apply(AppendRequest request) {
    if (!canHandle(request)) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Request not supported',
      );
    }
    final parseResult = helper.parseSource(request.source);
    final unit = parseResult.unit;
    if (unit == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Unable to parse source',
      );
    }
    final importPath = request.importPath!;
    final imports = helper.extractImports(unit);
    if (imports.contains(importPath)) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Import already exists',
      );
    }
    final updated = _insertImport(request.source, unit, importPath);
    return AppendResult(source: updated, changed: updated != request.source);
  }

  String _insertImport(String source, CompilationUnit unit, String importPath) {
    final importDirective = "import '$importPath';";
    final imports = unit.directives.whereType<ImportDirective>().toList();
    if (imports.isNotEmpty) {
      final lastImport = imports.last;
      final insertOffset = lastImport.end;
      return '${source.substring(0, insertOffset)}\n$importDirective'
          '${source.substring(insertOffset)}';
    }
    final exports = unit.directives.whereType<ExportDirective>().toList();
    if (exports.isNotEmpty) {
      final insertOffset = exports.last.end;
      return '${source.substring(0, insertOffset)}\n\n$importDirective'
          '${source.substring(insertOffset)}';
    }
    final library = unit.directives.whereType<LibraryDirective>().toList();
    if (library.isNotEmpty) {
      final insertOffset = library.first.end;
      return '${source.substring(0, insertOffset)}\n\n$importDirective'
          '${source.substring(insertOffset)}';
    }
    return '$importDirective\n$source';
  }
}
