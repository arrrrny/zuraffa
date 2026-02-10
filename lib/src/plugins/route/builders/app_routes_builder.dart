import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';
import 'extension_builder.dart';

class AppRoutesBuilder {
  final SpecLibrary specLibrary;
  final RouteExtensionBuilder extensionBuilder;
  final DartEmitter emitter;

  AppRoutesBuilder({
    this.specLibrary = const SpecLibrary(),
    this.extensionBuilder = const RouteExtensionBuilder(),
    DartEmitter? emitter,
  }) : emitter =
           emitter ??
           DartEmitter(orderDirectives: true, useNullSafetySyntax: true);

  String buildFile({
    required Map<String, String> routes,
    required List<ExtensionMethodSpec> extensionMethods,
  }) {
    final fields = routes.entries
        .map(
          (entry) => Field(
            (b) => b
              ..name = entry.key
              ..static = true
              ..modifier = FieldModifier.constant
              ..type = refer('String')
              ..assignment = Code("'${entry.value}'"),
          ),
        )
        .toList();

    final appRoutes = Class(
      (c) => c
        ..name = 'AppRoutes'
        ..fields.addAll(fields),
    );

    final extension = extensionBuilder.buildExtension(
      name: 'RouterExtension',
      onType: refer('BuildContext'),
      methods: extensionMethods,
    );

    final library = specLibrary.library(
      specs: [appRoutes, extension],
      directives: [
        Directive.import('package:flutter/material.dart'),
        Directive.import('package:go_router/go_router.dart'),
      ],
    );

    return specLibrary.emitLibrary(library);
  }

  String buildFieldSource(String name, String value) {
    final field = Field(
      (b) => b
        ..name = name
        ..static = true
        ..modifier = FieldModifier.constant
        ..type = refer('String')
        ..assignment = Code("'$value'"),
    );
    return field.accept(emitter).toString();
  }

  String buildMethodSource(ExtensionMethodSpec spec) {
    final method = extensionBuilder.buildMethod(spec);
    return method.accept(emitter).toString();
  }
}
