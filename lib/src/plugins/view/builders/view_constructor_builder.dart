import 'package:code_builder/code_builder.dart';

class ViewConstructorBuilder {
  const ViewConstructorBuilder();

  Constructor build({
    required List<Field> repoFields,
    required List<Field> routeFields,
    List<Parameter> customParameters = const [],
  }) {
    final parameters = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'key'
          ..named = true
          ..toSuper = true,
      ),
      Parameter(
        (p) => p
          ..name = 'routeObserver'
          ..named = true
          ..toSuper = true,
      ),
    ];

    parameters.addAll(
      repoFields.map(
        (field) => Parameter(
          (p) => p
            ..name = field.name
            ..toThis = true
            ..named = true
            ..required = true,
        ),
      ),
    );

    parameters.addAll(
      routeFields.map(
        (field) => Parameter(
          (p) => p
            ..name = field.name
            ..toThis = true
            ..named = true,
        ),
      ),
    );

    parameters.addAll(
      customParameters.map((param) => param.rebuild((p) => p..toThis = true)),
    );

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(parameters),
    );
  }
}
