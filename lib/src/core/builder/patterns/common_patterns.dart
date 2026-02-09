import 'package:code_builder/code_builder.dart';

class CommonPatterns {
  static Field finalField(
    String name,
    String type, {
    bool isLate = false,
  }) {
    return Field(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..modifier = FieldModifier.final$
        ..late = isLate,
    );
  }

  static Parameter requiredNamedParam(String name, String type) {
    return Parameter(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..named = true
        ..required = true,
    );
  }

  static Parameter optionalNamedParam(
    String name,
    String type, {
    Code? defaultTo,
  }) {
    return Parameter(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..named = true
        ..defaultTo = defaultTo,
    );
  }

  static Constructor constructor({
    String? name,
    bool isConst = false,
    Iterable<Parameter> parameters = const [],
    Iterable<Code> initializers = const [],
    Code? body,
  }) {
    return Constructor(
      (b) {
        b
          ..name = name
          ..constant = isConst
          ..initializers.addAll(initializers)
          ..body = body;
        for (final parameter in parameters) {
          if (parameter.named) {
            b.optionalParameters.add(parameter);
          } else {
            b.requiredParameters.add(parameter);
          }
        }
      },
    );
  }

  static Method abstractMethod({
    required String name,
    required String returnType,
    Iterable<Parameter> parameters = const [],
  }) {
    return Method(
      (b) {
        b
          ..name = name
          ..returns = refer(returnType)
          ..body = Code('throw UnimplementedError();');
        for (final parameter in parameters) {
          if (parameter.named) {
            b.optionalParameters.add(parameter);
          } else {
            b.requiredParameters.add(parameter);
          }
        }
      },
    );
  }
}
