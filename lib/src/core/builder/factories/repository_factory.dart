import 'package:code_builder/code_builder.dart';

import '../patterns/repository_patterns.dart';
import '../shared/spec_library.dart';

class RepositoryMethodSpec {
  final String name;
  final String returnType;
  final List<Parameter> parameters;

  const RepositoryMethodSpec({
    required this.name,
    required this.returnType,
    this.parameters = const [],
  });
}

class RepositorySpecConfig {
  final String className;
  final List<RepositoryMethodSpec> methods;
  final List<String> imports;

  const RepositorySpecConfig({
    required this.className,
    this.methods = const [],
    this.imports = const [],
  });
}

class RepositoryFactory {
  final SpecLibrary specLibrary;

  const RepositoryFactory({this.specLibrary = const SpecLibrary()});

  Library build(RepositorySpecConfig config) {
    final methodSpecs = config.methods
        .map(
          (method) => RepositoryPatterns.repositoryMethod(
            name: method.name,
            returnType: method.returnType,
            parameters: method.parameters,
          ),
        )
        .toList();

    final clazz = RepositoryPatterns.repositoryInterface(
      className: config.className,
      methods: methodSpecs,
    );

    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }
}
