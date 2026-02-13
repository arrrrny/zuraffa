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

  const AppendRequest.method({
    required this.source,
    required this.className,
    required this.memberSource,
  }) : target = AppendTarget.method,
       exportPath = null,
       importPath = null,
       functionName = null;

  const AppendRequest.field({
    required this.source,
    required this.className,
    required this.memberSource,
  }) : target = AppendTarget.field,
       exportPath = null,
       importPath = null,
       functionName = null;

  const AppendRequest.extensionMethod({
    required this.source,
    required this.className,
    required this.memberSource,
  }) : target = AppendTarget.extensionMethod,
       exportPath = null,
       importPath = null,
       functionName = null;

  const AppendRequest.functionStatement({
    required this.source,
    required this.functionName,
    required this.memberSource,
  }) : target = AppendTarget.functionStatement,
       className = null,
       exportPath = null,
       importPath = null;

  const AppendRequest.export({required this.source, required this.exportPath})
    : target = AppendTarget.exportDirective,
      className = null,
      memberSource = null,
      importPath = null,
      functionName = null;

  const AppendRequest.import({required this.source, required this.importPath})
    : target = AppendTarget.importDirective,
      className = null,
      memberSource = null,
      exportPath = null,
      functionName = null;
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
}
