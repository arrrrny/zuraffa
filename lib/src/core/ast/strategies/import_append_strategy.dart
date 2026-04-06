import '../ast_helper.dart';
import '../ast_modifier.dart';
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
    final updated = AstModifier.addImport(request.source, unit, importPath);
    return AppendResult(
      source: updated,
      changed: updated != request.source,
      message: updated != request.source
          ? 'Import added'
          : 'Import already exists',
    );
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
    final parseResult = helper.parseSource(request.source);
    final unit = parseResult.unit;
    if (unit == null) {
      return AppendResult(
        source: request.source,
        changed: false,
        message: 'Unable to parse source',
      );
    }
    final updated = AstModifier.removeImport(
      request.source,
      unit,
      request.importPath!,
    );
    return AppendResult(
      source: updated,
      changed: updated != request.source,
      message: updated != request.source
          ? 'Import removed'
          : 'Import not found',
    );
  }
}
