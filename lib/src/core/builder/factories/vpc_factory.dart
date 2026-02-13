import 'package:code_builder/code_builder.dart';

import '../patterns/vpc_patterns.dart';
import '../shared/spec_library.dart';

class VpcSpecConfig {
  final String className;
  final String? baseClass;
  final List<Field> fields;
  final List<Method> methods;
  final List<Constructor> constructors;
  final List<String> imports;

  const VpcSpecConfig({
    required this.className,
    this.baseClass,
    this.fields = const [],
    this.methods = const [],
    this.constructors = const [],
    this.imports = const [],
  });
}

class VpcFactory {
  final SpecLibrary specLibrary;

  const VpcFactory({this.specLibrary = const SpecLibrary()});

  Library buildController(VpcSpecConfig config) {
    final clazz = VpcPatterns.controllerClass(
      className: config.className,
      baseClass: config.baseClass,
      fields: config.fields,
      methods: config.methods,
      constructors: config.constructors,
    );
    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }

  Library buildPresenter(VpcSpecConfig config) {
    final clazz = VpcPatterns.presenterClass(
      className: config.className,
      baseClass: config.baseClass,
      fields: config.fields,
      methods: config.methods,
    );
    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }

  Library buildState(VpcSpecConfig config) {
    final clazz = VpcPatterns.stateClass(
      className: config.className,
      fields: config.fields,
      constructors: config.constructors,
    );
    return specLibrary.library(
      specs: [clazz],
      directives: config.imports.map(Directive.import),
    );
  }
}
