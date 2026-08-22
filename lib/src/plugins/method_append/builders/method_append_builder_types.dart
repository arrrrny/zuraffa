part of 'method_append_builder.dart';

extension MethodAppendBuilderTypes on MethodAppendBuilder {
  Reference _returnType(String useCaseType, String returnsType) {
    switch (useCaseType) {
      case 'stream':
        // Avoid double-wrapping when the caller already passes a Stream<...>
        // (e.g. `--returns "Stream<int>" --type stream`); issue #413.
        if (returnsType.startsWith('Stream<') || returnsType == 'Stream') {
          return refer(returnsType);
        }
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
        // Avoid double-wrapping when the caller already passes a Future<...>
        // (e.g. `--returns "Future<void>" --type usecase`); issue #413.
        if (returnsType.startsWith('Future<') || returnsType == 'Future') {
          return refer(returnsType);
        }
        return TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..types.add(refer(returnsType)),
        );
    }
  }

  Expression _primitiveValue(String type) {
    switch (type) {
      case 'String':
        return literalString('mock_value');
      case 'int':
        return literalNum(1);
      case 'double':
        return literalNum(1.0);
      case 'bool':
        return literalBool(true);
      case 'DateTime':
        return refer('DateTime').property('now').call([]);
      default:
        return literalNull;
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
