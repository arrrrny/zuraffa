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
  final String initialMethodCall;
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
    final controllerCall = '${spec.controllerName}($presenterCall)';

    final createStateMethod = Method(
      (m) => m
        ..name = 'createState'
        ..annotations.add(refer('override'))
        ..returns = refer('State<${spec.viewName}>')
        ..body = Code('''
return _${spec.viewName}State(
  $controllerCall,
);'''),
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
        ..initializers.add(Code('super(controller)')),
    );

    final onInitState = lifecycleBuilder.buildOnInitState(
      initialCall: spec.initialMethodCall,
    );

    final builderBody = spec.withState
        ? '''
      final viewState = controller.viewState;
      return Container();
'''
        : '''
      return Container();
''';

    final viewGetter = Method(
      (m) => m
        ..name = 'view'
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..returns = refer('Widget')
        ..body = Code('''
return Scaffold(
  key: globalKey,
  appBar: AppBar(
    title: const Text('${spec.entityName}'),
  ),
  body: ControlledWidgetBuilder<${spec.controllerName}>(
    builder: (context, controller) {
${builderBody.trimRight()}
    },
  ),
);'''),
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

  String _presenterCall(ViewClassSpec spec) {
    if (spec.repoPresenterArgs.isEmpty) {
      return '${spec.presenterName}()';
    }
    return '${spec.presenterName}(${spec.repoPresenterArgs.join(', ')})';
  }
}
