import 'package:code_builder/code_builder.dart';

class MockTypeHelper {
  const MockTypeHelper();

  Reference futureVoidType() {
    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..types.add(refer('void')),
    );
  }

  Reference listOf(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'List'
        ..types.add(refer(entityName)),
    );
  }

  Reference listOfFuture(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..types.add(listOf(entityName)),
    );
  }

  Reference listOfStream(String entityName) {
    return TypeReference(
      (b) => b
        ..symbol = 'Stream'
        ..types.add(listOf(entityName)),
    );
  }
}
