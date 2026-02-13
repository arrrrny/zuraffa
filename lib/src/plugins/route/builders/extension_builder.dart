import 'package:code_builder/code_builder.dart';

class ExtensionMethodSpec {
  final String name;
  final Expression body;
  final List<Parameter> parameters;
  final Reference returnType;
  final bool lambda;

  const ExtensionMethodSpec({
    required this.name,
    required this.body,
    this.parameters = const [],
    this.returnType = const Reference('void'),
    this.lambda = true,
  });
}

class RouteExtensionBuilder {
  const RouteExtensionBuilder();

  Method buildMethod(ExtensionMethodSpec spec) {
    return Method(
      (m) => m
        ..name = spec.name
        ..returns = spec.returnType
        ..requiredParameters.addAll(spec.parameters)
        ..lambda = spec.lambda
        ..body = spec.lambda
            ? spec.body.code
            : Block((b) => b..statements.add(spec.body.statement)),
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
