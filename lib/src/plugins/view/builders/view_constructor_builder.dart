import 'package:code_builder/code_builder.dart';

class ViewConstructorBuilder {
  const ViewConstructorBuilder();

  Constructor build({
    required List<Field> repoFields,
    required List<Field> routeFields,
  }) {
    final parameters = <Parameter>[
      Parameter(
        (p) => p
          ..name = 'key'
          ..type = refer('Key?')
          ..named = true,
      ),
      Parameter(
        (p) => p
          ..name = 'routeObserver'
          ..type = refer('RouteObserver<ModalRoute<void>>?')
          ..named = true,
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

    return Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(parameters)
        ..initializers.add(
          refer('super').call([], {
            'key': refer('key'),
            'routeObserver': refer('routeObserver'),
          }).code,
        ),
    );
  }
}
