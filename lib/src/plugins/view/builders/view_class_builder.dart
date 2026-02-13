import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';
import 'lifecycle_builder.dart';
import 'view_constructor_builder.dart';

class ViewClassSpec {
  final String viewName;
  final String controllerName;
  final String presenterName;
  final String entityName;
  final List<Field> repoFields;
  final List<Field> routeFields;
  final List<String> repoPresenterArgs;
  final Block initialMethodCall;
  final List<String> imports;
  final bool withState;

  const ViewClassSpec({
    required this.viewName,
    required this.controllerName,
    required this.presenterName,
    required this.entityName,
    required this.repoFields,
    required this.routeFields,
    required this.repoPresenterArgs,
    required this.initialMethodCall,
    required this.imports,
    required this.withState,
  });
}

class ViewClassBuilder {
  final SpecLibrary specLibrary;
  final ViewConstructorBuilder constructorBuilder;
  final ViewLifecycleBuilder lifecycleBuilder;

  const ViewClassBuilder({
    this.specLibrary = const SpecLibrary(),
    this.constructorBuilder = const ViewConstructorBuilder(),
    this.lifecycleBuilder = const ViewLifecycleBuilder(),
  });

  String build(ViewClassSpec spec) {
    final viewClass = _buildViewClass(spec);
    final stateClass = _buildStateClass(spec);
    final directives = spec.imports.toSet().map(Directive.import).toList();

    final library = specLibrary.library(
      specs: [viewClass, stateClass],
      directives: directives,
    );

    return specLibrary.emitLibrary(library);
  }

  Class _buildViewClass(ViewClassSpec spec) {
    final constructor = constructorBuilder.build(
      repoFields: spec.repoFields,
      routeFields: spec.routeFields,
    );

    final presenterCall = _presenterCall(spec);
    final controllerCall = refer(spec.controllerName).call([presenterCall]);

    final createStateMethod = Method(
      (m) => m
        ..name = 'createState'
        ..annotations.add(refer('override'))
        ..returns = refer('State<${spec.viewName}>')
        ..body = Block(
          (b) => b
            ..statements.add(
              refer(
                '_${spec.viewName}State',
              ).call([controllerCall]).returned.statement,
            ),
        ),
    );

    return Class(
      (c) => c
        ..name = spec.viewName
        ..extend = refer('CleanView')
        ..fields.addAll([...spec.repoFields, ...spec.routeFields])
        ..constructors.add(constructor)
        ..methods.add(createStateMethod),
    );
  }

  Class _buildStateClass(ViewClassSpec spec) {
    final stateConstructor = Constructor(
      (c) => c
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'controller'
              ..type = refer(spec.controllerName),
          ),
        )
        ..initializers.add(refer('super').call([refer('controller')]).code),
    );

    final onInitState = lifecycleBuilder.buildOnInitState(
      initialCall: spec.initialMethodCall,
    );

    final builderBody = _buildBuilderBody(spec);
    final builderClosure = Method(
      (m) => m
        ..requiredParameters.addAll([
          Parameter((p) => p..name = 'context'),
          Parameter((p) => p..name = 'controller'),
        ])
        ..body = builderBody,
    ).closure;

    final viewGetter = Method(
      (m) => m
        ..name = 'view'
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..returns = refer('Widget')
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('Scaffold')
                  .call([], {
                    'key': refer('globalKey'),
                    'appBar': refer('AppBar').call([], {
                      'title': refer(
                        'Text',
                      ).constInstance([literalString(spec.entityName)]),
                    }),
                    'body': refer(
                      'ControlledWidgetBuilder<${spec.controllerName}>',
                    ).call([], {'builder': builderClosure}),
                  })
                  .returned
                  .statement,
            ),
        ),
    );

    return Class(
      (c) => c
        ..name = '_${spec.viewName}State'
        ..extend = refer(
          'CleanViewState<${spec.viewName}, ${spec.controllerName}>',
        )
        ..constructors.add(stateConstructor)
        ..methods.addAll([onInitState, viewGetter]),
    );
  }

  Expression _presenterCall(ViewClassSpec spec) {
    if (spec.repoPresenterArgs.isEmpty) {
      return refer(spec.presenterName).call([]);
    }
    final args = <String, Expression>{};
    for (final arg in spec.repoPresenterArgs) {
      final parts = arg.split(':');
      if (parts.length != 2) continue;
      args[parts[0].trim()] = refer(parts[1].trim());
    }
    return refer(spec.presenterName).call([], args);
  }

  Block _buildBuilderBody(ViewClassSpec spec) {
    if (spec.withState) {
      return Block(
        (b) => b
          ..statements.add(
            declareFinal(
              'viewState',
            ).assign(refer('controller').property('viewState')).statement,
          )
          ..statements.add(
            refer('Container')
                .call([], {
                  'key': refer(
                    'ValueKey',
                  ).call([refer('viewState').property('hashCode')]),
                })
                .returned
                .statement,
          ),
      );
    }
    return Block(
      (b) => b..statements.add(refer('Container').call([]).returned.statement),
    );
  }
}
