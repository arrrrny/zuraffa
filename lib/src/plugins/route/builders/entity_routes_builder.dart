import 'package:code_builder/code_builder.dart';

import '../../../core/builder/factories/route_factory.dart';
import '../../../core/builder/shared/spec_library.dart';

class EntityRoutesBuilder {
  final SpecLibrary specLibrary;
  final RouteFactory routeFactory;
  final DartEmitter emitter;

  EntityRoutesBuilder({
    this.specLibrary = const SpecLibrary(),
    this.routeFactory = const RouteFactory(),
    DartEmitter? emitter,
  }) : emitter =
           emitter ??
           DartEmitter(orderDirectives: true, useNullSafetySyntax: true);

  String buildFile({
    required String className,
    required Map<String, String> routes,
    required String routesGetterName,
    required List<Expression> goRoutes,
    required List<String> imports,
    String? leadingComment,
  }) {
    final routesClass = routeFactory.build(
      RouteSpecConfig(className: className, routes: routes),
    );

    final getRoutesMethod = Method(
      (m) => m
        ..name = routesGetterName
        ..returns = refer('List<GoRoute>')
        ..body = literalList(goRoutes).returned.statement,
    );

    final library = specLibrary.library(
      specs: [...routesClass.body, getRoutesMethod],
      directives: imports.map(Directive.import),
    );

    return specLibrary.emitLibrary(library, leadingComment: leadingComment);
  }

  String buildFieldSource(String name, String value) {
    final field = Field(
      (b) => b
        ..name = name
        ..static = true
        ..modifier = FieldModifier.constant
        ..type = refer('String')
        ..assignment = literalString(value).code,
    );
    return field.accept(emitter).toString();
  }

  String buildRouteSource(Expression routeExpr) {
    return routeExpr.accept(emitter).toString();
  }
}
