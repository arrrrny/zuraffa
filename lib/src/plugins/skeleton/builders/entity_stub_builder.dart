/// Generates Dart entity stub source via code_builder.
library;

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../models/bone.dart';

/// Generates a Dart entity stub file for an [EntityStub].
class EntityStubBuilder {
  /// Creates an [EntityStubBuilder].
  EntityStubBuilder({DartEmitter? emitter})
    : _emitter =
          emitter ??
          DartEmitter(orderDirectives: true, useNullSafetySyntax: true);

  final DartEmitter _emitter;

  /// Returns the formatted Dart source for [stub].
  String build(EntityStub stub) {
    final fields = <Field>[];
    for (final field in stub.fields) {
      fields.add(
        Field(
          (f) => f
            ..name = field.name
            ..type = refer(field.type)
            ..modifier = FieldModifier.final$,
        ),
      );
    }

    final clazz = Class(
      (c) => c
        ..name = stub.name
        ..fields.addAll(fields)
        ..constructors.add(
          Constructor(
            (ctor) => ctor
              ..constant = true
              ..requiredParameters.addAll([
                for (final field in stub.fields)
                  Parameter(
                    (p) => p
                      ..name = field.name
                      ..toThis = true,
                  ),
              ]),
          ),
        ),
    );

    final library = Library((lib) => lib..body.add(clazz));

    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(library.accept(_emitter).toString());
  }
}
