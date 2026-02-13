import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';

class RegistrationBuilder {
  final SpecLibrary specLibrary;

  const RegistrationBuilder({this.specLibrary = const SpecLibrary()});

  String buildRegistrationFile({
    required String functionName,
    required List<String> imports,
    required Block body,
  }) {
    final method = Method(
      (m) => m
        ..name = functionName
        ..returns = refer('void')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'getIt'
              ..type = refer('GetIt'),
          ),
        )
        ..body = body,
    );

    final library = specLibrary.library(
      specs: [method],
      directives: imports.map(Directive.import),
    );

    return specLibrary.emitLibrary(library);
  }

  String buildIndexFile({
    required String functionName,
    required List<Code> registrations,
    List<Directive> directives = const [],
  }) {
    final method = Method(
      (m) => m
        ..name = functionName
        ..returns = refer('void')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'getIt'
              ..type = refer('GetIt'),
          ),
        )
        ..body = Block((b) => b..statements.addAll(registrations)),
    );

    final library = specLibrary.library(
      specs: [method],
      directives: directives,
    );

    return specLibrary.emitLibrary(library);
  }
}
