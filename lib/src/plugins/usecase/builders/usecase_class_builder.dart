import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';

class UseCaseClassSpec {
  final String className;
  final String? baseClass;
  final bool isAbstract;
  final List<Field> fields;
  final List<Constructor> constructors;
  final List<Method> methods;
  final List<String> imports;

  const UseCaseClassSpec({
    required this.className,
    this.baseClass,
    this.isAbstract = false,
    this.fields = const [],
    this.constructors = const [],
    this.methods = const [],
    this.imports = const [],
  });
}

class UseCaseClassBuilder {
  final SpecLibrary specLibrary;

  const UseCaseClassBuilder({this.specLibrary = const SpecLibrary()});

  Library buildLibrary(UseCaseClassSpec spec) {
    final clazz = Class(
      (b) => b
        ..name = spec.className
        ..extend = spec.baseClass != null ? refer(spec.baseClass!) : null
        ..abstract = spec.isAbstract
        ..fields.addAll(spec.fields)
        ..constructors.addAll(spec.constructors)
        ..methods.addAll(spec.methods),
    );

    final directives = spec.imports.toSet().map(Directive.import).toList();

    return specLibrary.library(
      specs: [clazz],
      directives: directives,
    );
  }

  String build(UseCaseClassSpec spec, {bool format = true}) {
    return specLibrary.emitLibrary(
      buildLibrary(spec),
      format: format,
    );
  }
}
