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

    // Check for standard imports
    final imports = unit.directives.whereType<ImportDirective>().toList();
    if (imports.isNotEmpty) {
      final lastImport = imports.last;
      final insertOffset = lastImport.end;
      return '${source.substring(0, insertOffset)}\n$importDirective'
          '${source.substring(insertOffset)}';
    }

    // If no standard imports, check for any directive as a fallback for placement
    if (unit.directives.isNotEmpty) {
      final lastDirective = unit.directives.last;
      final insertOffset = lastDirective.end;
      return '${source.substring(0, insertOffset)}\n$importDirective'
          '${source.substring(insertOffset)}';
    }

    return '$importDirective\n$source';
  }

  @override
  AppendResult undo(AppendRequest request) {
    if (!canHandle(request)) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Request not supported',
      );
    }
    final importDirective = "import '${request.importPath!}';";
    if (request.source.contains(importDirective)) {
      final updated = request.source.replaceFirst(importDirective, '').trim();
      return AppendResult(
        source: updated,
        changed: true,
        message: 'Import removed',
      );
    }
    return AppendResult(
      source: request.source,
      changed: false,
      message: 'Import not found',
    );
  }
}
