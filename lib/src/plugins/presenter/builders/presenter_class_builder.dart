import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';

class PresenterClassSpec {
  final String className;
  final List<Field> fields;
  final Constructor constructor;
  final List<Method> methods;
  final List<String> imports;

  const PresenterClassSpec({
    required this.className,
    required this.fields,
    required this.constructor,
    required this.methods,
    required this.imports,
  });
}

class PresenterClassBuilder {
  final SpecLibrary specLibrary;

  const PresenterClassBuilder({this.specLibrary = const SpecLibrary()});

  String build(PresenterClassSpec spec) {
    final clazz = Class(
      (b) => b
        ..name = spec.className
        ..extend = refer('Presenter')
        ..fields.addAll(spec.fields)
        ..constructors.add(spec.constructor)
        ..methods.addAll(spec.methods),
    );

    final directives = spec.imports.toSet().map(Directive.import).toList();

    return specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );
  }
}
