import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';

class ServiceLocatorBuilder {
  final SpecLibrary specLibrary;

  const ServiceLocatorBuilder({this.specLibrary = const SpecLibrary()});

  String build({String coreImport = 'package:zuraffa/zuraffa.dart'}) {
    final directives = [
      Directive.import(coreImport),
      Directive.export(coreImport, show: ['GetIt']),
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
