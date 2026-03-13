class ParsedUseCaseInfo {
  final String className;
  final String fieldName;
  final String? paramsType;
  final String? returnsType;
  final String? useCaseType;

  const ParsedUseCaseInfo({
    required this.className,
    required this.fieldName,
    this.paramsType,
    this.returnsType,
    this.useCaseType,
  });
}
