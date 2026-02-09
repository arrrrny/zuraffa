import 'package:code_builder/code_builder.dart';

import '../shared/spec_library.dart';

class RouteSpecConfig {
  final String className;
  final Map<String, String> routes;
  final List<String> imports;

  const RouteSpecConfig({
    required this.className,
    required this.routes,
    this.imports = const [],
  });
}

class RouteFactory {
  final SpecLibrary specLibrary;

  const RouteFactory({this.specLibrary = const SpecLibrary()});

  Library build(RouteSpecConfig config) {
    final fields = config.routes.entries
        .map(
          (entry) => Field(
            (b) => b
              ..name = entry.key
              ..static = true
              ..modifier = FieldModifier.constant
              ..type = refer('String')
              ..assignment = Code("'${entry.value}'"),
          ),
        )
        .toList();

    final clazz = Class(
      (b) => b
        ..name = config.className
        ..fields.addAll(fields),
    );

    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }
}
