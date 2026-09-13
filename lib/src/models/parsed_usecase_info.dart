class ParsedUseCaseInfo {
  final String className;
  final String fieldName;
  final String? paramsType;
  final String? returnsType;
  final String? useCaseType;

  /// The number of parameters the member declares. Interface extraction
  /// carries this because a `'NoParams'` [paramsType] cannot distinguish
  /// "declares no parameter" from "declares a real `NoParams params`
  /// parameter" (issue #1570 review: a repaired parameter-less member
  /// must not gain a required `params` argument). Defaults to 1 — the
  /// shape every non-extracted construction site describes.
  final int parameterCount;

  /// True when the member is declared as a getter (`Stream<bool> get
  /// isInitialized`) rather than a method. Defaults to false.
  final bool isGetter;

  const ParsedUseCaseInfo({
    required this.className,
    required this.fieldName,
    this.paramsType,
    this.returnsType,
    this.useCaseType,
    this.parameterCount = 1,
    this.isGetter = false,
  });
}
