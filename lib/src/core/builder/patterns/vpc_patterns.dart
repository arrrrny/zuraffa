import 'package:code_builder/code_builder.dart';

import 'common_patterns.dart';

class VpcPatterns {
  static Class controllerClass({
    required String className,
    String? baseClass,
    Iterable<Field> fields = const [],
    Iterable<Method> methods = const [],
    Iterable<Constructor> constructors = const [],
  }) {
    return Class(
      (b) => b
        ..name = className
        ..extend = baseClass != null ? refer(baseClass) : null
        ..fields.addAll(fields)
        ..constructors.addAll(constructors)
        ..methods.addAll(methods),
    );
  }

  static Class presenterClass({
    required String className,
    String? baseClass,
    Iterable<Field> fields = const [],
    Iterable<Method> methods = const [],
  }) {
    return Class(
      (b) => b
        ..name = className
        ..extend = baseClass != null ? refer(baseClass) : null
        ..fields.addAll(fields)
        ..methods.addAll(methods),
    );
  }

  static Class stateClass({
    required String className,
    Iterable<Field> fields = const [],
    Iterable<Constructor> constructors = const [],
  }) {
    return Class(
      (b) => b
        ..name = className
        ..fields.addAll(fields)
        ..constructors.addAll(
          constructors.isEmpty
              ? [
                CommonPatterns.constructor(
                  parameters: fields.map(
                    (field) => CommonPatterns.optionalNamedParam(
                      field.name,
                      field.type?.symbol ?? 'dynamic',
                    ),
                  ),
                ),
              ]
              : constructors,
        ),
    );
  }
}
