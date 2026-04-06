import '../ast_helper.dart';
import '../ast_modifier.dart';
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
    final updated = AstModifier.addExport(request.source, unit, exportPath);
    return AppendResult(
      source: updated,
      changed: updated != request.source,
      message: updated != request.source
          ? 'Export added'
          : 'Export already exists',
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
    final updated = AstModifier.removeExport(
      request.source,
      unit,
      request.exportPath!,
    );
    return AppendResult(
      source: updated,
      changed: updated != request.source,
      message: updated != request.source
          ? 'Export removed'
          : 'Export not found',
    );
  }
}
