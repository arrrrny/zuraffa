import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';

class ServiceLocatorBuilder {
  final SpecLibrary specLibrary;

  const ServiceLocatorBuilder({this.specLibrary = const SpecLibrary()});

  String build() {
    final directives = [
      Directive.import('package:get_it/get_it.dart'),
      Directive.export('package:get_it/get_it.dart', show: ['GetIt']),
      Directive.export('index.dart', show: ['setupDependencies']),
    ];

    final getItVar = Field(
      (f) => f
        ..name = 'getIt'
        ..type = refer('GetIt')
        ..modifier = FieldModifier.final$
        ..assignment = refer('GetIt.instance').code,
    );

    final library = specLibrary.library(
      specs: [getItVar],
      directives: directives,
    );

    return specLibrary.emitLibrary(library);
  }
}
