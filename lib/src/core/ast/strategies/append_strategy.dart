enum AppendTarget {
  method,
  field,
  extensionMethod,
  functionStatement,
  exportDirective,
  importDirective,
}

class AppendRequest {
  final AppendTarget target;
  final String source;
  final String? className;
  final String? memberSource;
  final String? exportPath;
  final String? importPath;
  final String? functionName;
  final bool force;

  const AppendRequest.method({
    required this.source,
    required this.className,
    required this.memberSource,
    this.force = false,
  }) : target = AppendTarget.method,
       exportPath = null,
       importPath = null,
       functionName = null;

  const AppendRequest.field({
    required this.source,
    required this.className,
    required this.memberSource,
    this.force = false,
  }) : target = AppendTarget.field,
       exportPath = null,
       importPath = null,
       functionName = null;

  const AppendRequest.extensionMethod({
    required this.source,
    required this.className,
    required this.memberSource,
    this.force = false,
  }) : target = AppendTarget.extensionMethod,
       exportPath = null,
       importPath = null,
       functionName = null;

  const AppendRequest.functionStatement({
    required this.source,
    required this.functionName,
    required this.memberSource,
    this.force = false,
  }) : target = AppendTarget.functionStatement,
       className = null,
       exportPath = null,
       importPath = null;

  const AppendRequest.export({required this.source, required this.exportPath})
    : target = AppendTarget.exportDirective,
      className = null,
      memberSource = null,
      importPath = null,
      functionName = null,
      force = false;

  const AppendRequest.import({required this.source, required this.importPath})
    : target = AppendTarget.importDirective,
      className = null,
      memberSource = null,
      exportPath = null,
      functionName = null,
      force = false;
}

class AppendResult {
  final String source;
  final bool changed;
  final String? message;

  const AppendResult({
    required this.source,
    required this.changed,
    this.message,
  });
}

abstract class AppendStrategy {
  bool canHandle(AppendRequest request);
  AppendResult apply(AppendRequest request);
  AppendResult undo(AppendRequest request);
}
