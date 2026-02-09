import 'package:analyzer/dart/ast/ast.dart';

import '../ast_helper.dart';
import 'append_strategy.dart';

class ExportAppendStrategy implements AppendStrategy {
  final AstHelper helper;

  const ExportAppendStrategy({this.helper = const AstHelper()});

  @override
  bool canHandle(AppendRequest request) {
    return request.target == AppendTarget.exportDirective &&
        request.exportPath != null;
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
    final exportPath = request.exportPath!;
    final exports = helper.extractExports(unit);
    if (exports.contains(exportPath)) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Export already exists',
      );
    }
    final updated = _insertExport(request.source, unit, exportPath);
    return AppendResult(source: updated, changed: updated != request.source);
  }

  String _insertExport(
    String source,
    CompilationUnit unit,
    String exportPath,
  ) {
    final exportDirective = "export '$exportPath';";
    final exports = unit.directives.whereType<ExportDirective>().toList();
    if (exports.isNotEmpty) {
      final lastExport = exports.last;
      final insertOffset = lastExport.end;
      return '${source.substring(0, insertOffset)}\n$exportDirective'
          '${source.substring(insertOffset)}';
    }
    final library = unit.directives.whereType<LibraryDirective>().toList();
    if (library.isNotEmpty) {
      final insertOffset = library.first.end;
      return '${source.substring(0, insertOffset)}\n\n$exportDirective'
          '${source.substring(insertOffset)}';
    }
    return '$exportDirective\n$source';
  }
}
