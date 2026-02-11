part of 'method_append_builder.dart';

extension MethodAppendBuilderTypes on MethodAppendBuilder {
  Reference _returnType(String useCaseType, String returnsType) {
    switch (useCaseType) {
      case 'stream':
        return TypeReference(
          (b) => b
            ..symbol = 'Stream'
            ..types.add(refer(returnsType)),
        );
      case 'completable':
        return TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..types.add(refer('void')),
        );
      case 'sync':
        return refer(returnsType);
      default:
        return TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..types.add(refer(returnsType)),
        );
    }
  }
}

class MethodAppendResult {
  final List<GeneratedFile> updatedFiles;
  final List<String> warnings;

  MethodAppendResult(this.updatedFiles, this.warnings);
}

extension on Expression {
  Expression maybeAwaited(bool condition) => condition ? awaited : this;
}
