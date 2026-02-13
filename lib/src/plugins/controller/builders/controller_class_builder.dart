import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';
import 'stateful_controller_builder.dart';

class ControllerClassSpec {
  final String className;
  final String presenterName;
  final String? stateClassName;
  final List<Method> methods;
  final List<String> imports;
  final bool withState;

  const ControllerClassSpec({
    required this.className,
    required this.presenterName,
    required this.methods,
    required this.imports,
    this.stateClassName,
    this.withState = false,
  });
}

class ControllerClassBuilder {
  final SpecLibrary specLibrary;
  final StatefulControllerBuilder statefulBuilder;

  const ControllerClassBuilder({
    this.specLibrary = const SpecLibrary(),
    this.statefulBuilder = const StatefulControllerBuilder(),
  });

  String build(ControllerClassSpec spec) {
    final constructors = <Constructor>[];
    final fields = <Field>[];

    fields.add(
      Field(
        (f) => f
          ..modifier = FieldModifier.final$
          ..type = refer(spec.presenterName)
          ..name = '_presenter',
      ),
    );

    final ctor = Constructor((c) {
      c.requiredParameters.add(
        Parameter(
          (p) => p
            ..name = '_presenter'
            ..toThis = true,
        ),
      );
    });
    constructors.add(ctor);

    final stateClassName = spec.stateClassName;
    if (spec.withState && stateClassName != null) {
      spec.methods.insert(
        0,
        statefulBuilder.buildCreateInitialState(stateClassName),
      );
    }

    final onDisposed = Method(
      (m) => m
        ..name = 'onDisposed'
        ..annotations.add(refer('override'))
        ..returns = refer('void')
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('_presenter').property('dispose').call([]).statement,
            )
            ..statements.add(
              refer('super').property('onDisposed').call([]).statement,
            ),
        ),
    );
    spec.methods.add(onDisposed);

    final clazz = Class(
      (b) => b
        ..name = spec.className
        ..extend = refer('Controller')
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(spec.methods)
        ..mixins.addAll(
          spec.withState && spec.stateClassName != null
              ? [refer('StatefulController<${spec.stateClassName}>')]
              : const [],
        ),
    );

    final directives = spec.imports.toSet().map(Directive.import).toList();
    return specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );
  }
}
