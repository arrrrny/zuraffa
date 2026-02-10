enum AppendTarget { method, field, extensionMethod, exportDirective }

class AppendRequest {
  final AppendTarget target;
  final String source;
  final String? className;
  final String? memberSource;
  final String? exportPath;

  const AppendRequest.method({
    required this.source,
    required this.className,
    required this.memberSource,
  }) : target = AppendTarget.method,
       exportPath = null;

  const AppendRequest.field({
    required this.source,
    required this.className,
    required this.memberSource,
  }) : target = AppendTarget.field,
       exportPath = null;

  const AppendRequest.extensionMethod({
    required this.source,
    required this.className,
    required this.memberSource,
  }) : target = AppendTarget.extensionMethod,
       exportPath = null;

  const AppendRequest.export({required this.source, required this.exportPath})
    : target = AppendTarget.exportDirective,
      className = null,
      memberSource = null;
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
