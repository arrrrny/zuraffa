import 'package:code_builder/code_builder.dart';

class ExtensionMethodSpec {
  final String name;
  final String body;
  final List<Parameter> parameters;
  final String returnType;
  final bool lambda;

  const ExtensionMethodSpec({
    required this.name,
    required this.body,
    this.parameters = const [],
    this.returnType = 'void',
    this.lambda = true,
  });
}

class RouteExtensionBuilder {
  const RouteExtensionBuilder();

  Method buildMethod(ExtensionMethodSpec spec) {
    return Method(
      (m) => m
        ..name = spec.name
        ..returns = refer(spec.returnType)
        ..requiredParameters.addAll(spec.parameters)
        ..lambda = spec.lambda
        ..body = Code(spec.body),
    );
  }

  Extension buildExtension({
    required String name,
    required Reference onType,
    required List<ExtensionMethodSpec> methods,
  }) {
    return Extension(
      (e) => e
        ..name = name
        ..on = onType
        ..methods.addAll(methods.map(buildMethod)),
    );
  }
}
