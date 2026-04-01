import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

import '../../../core/builder/shared/spec_library.dart';
import 'lifecycle_builder.dart';
import 'view_constructor_builder.dart';

class ViewClassSpec {
  final String viewName;
  final String controllerName;
  final String presenterName;
  final String? entityName;
  final String? entityCamel;
  final String? stateClassName;
  final List<Field> repoFields;
  final List<Field> routeFields;
  final List<Parameter> customParameters;
  final List<String> repoPresenterArgs;
  final Block initialMethodCall;
  final List<String> imports;
  final bool withState;
  final bool isCustom;
  final bool isStateful;

  const ViewClassSpec({
    required this.viewName,
    required this.controllerName,
    required this.presenterName,
    required this.repoFields,
    required this.routeFields,
    required this.repoPresenterArgs,
    required this.initialMethodCall,
    required this.imports,
    required this.withState,
    this.customParameters = const [],
    this.entityName,
    this.entityCamel,
    this.isCustom = false,
    this.isStateful = false,
    this.stateClassName,
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

  static const _ignoreComment = '// ignore_for_file: no_logic_in_create_state';

  String build(ViewClassSpec spec, {String? leadingComment}) {
    if (spec.isCustom) {
      return _buildCustomView(spec, leadingComment: leadingComment);
    }
    final viewClass = _buildViewClass(spec);
    final stateClass = _buildStateClass(spec);
    final directives = spec.imports.toSet().map(Directive.import).toList();

    final library = specLibrary.library(
      specs: [viewClass, stateClass],
      directives: directives,
    );

    final comment = leadingComment != null
        ? '$leadingComment\n$_ignoreComment'
        : _ignoreComment;

    final emitter = DartEmitter(
      useNullSafetySyntax: true,
      orderDirectives: true,
    );
    var raw = library.accept(emitter).toString();
    if (comment.isNotEmpty) {
      raw = '$comment\n$raw';
    }

    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(raw);
  }

  String _buildCustomView(ViewClassSpec spec, {String? leadingComment}) {
    if (spec.isStateful) {
      return _buildCustomStatefulView(spec, leadingComment: leadingComment);
    }
    final viewClass = Class(
      (c) => c
        ..name = spec.viewName
        ..extend = refer('StatelessWidget')
        ..fields.addAll(
          spec.customParameters.map(
            (p) => Field(
              (f) => f
                ..name = p.name
                ..type = p.type
                ..modifier = FieldModifier.final$,
            ),
          ),
        )
        ..constructors.add(
          Constructor(
            (c) => c
              ..constant = true
              ..optionalParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'key'
                    ..named = true
                    ..toSuper = true,
                ),
              )
              ..optionalParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'routeObserver'
                    ..named = true
                    ..toSuper = true,
                ),
              )
              ..optionalParameters.addAll(
                spec.customParameters.map(
                  (p) => p.rebuild((b) => b..toThis = true),
                ),
              ),
          ),
        )
        ..methods.add(
          Method(
            (m) => m
              ..name = 'build'
              ..annotations.add(refer('override'))
              ..returns = refer('Widget')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'context'
                    ..type = refer('BuildContext'),
                ),
              )
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer('Scaffold')
                        .newInstance([], {
                          'appBar': refer('AppBar').newInstance([], {
                            'title': refer('Text').newInstance([
                              literalString(spec.entityName ?? spec.viewName),
                            ]),
                          }),
                          'body': refer('Center').newInstance([], {
                            'child': refer('Text').newInstance([
                              literalString('${spec.viewName} is working!'),
                            ]),
                          }),
                        })
                        .returned
                        .statement,
                  ),
              ),
          ),
        ),
    );

    final directives = spec.imports.toSet().map(Directive.import).toList();
    final library = specLibrary.library(
      specs: [viewClass],
      directives: directives,
    );

    final emitter = DartEmitter(
      useNullSafetySyntax: true,
      orderDirectives: true,
    );
    var raw = library.accept(emitter).toString();
    if (leadingComment != null) {
      raw = '$leadingComment\n$raw';
    }

    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(raw);
  }

  String _buildCustomStatefulView(
    ViewClassSpec spec, {
    String? leadingComment,
  }) {
    final viewClass = Class(
      (c) => c
        ..name = spec.viewName
        ..extend = refer('StatefulWidget')
        ..fields.addAll(
          spec.customParameters.map(
            (p) => Field(
              (f) => f
                ..name = p.name
                ..type = p.type
                ..modifier = FieldModifier.final$,
            ),
          ),
        )
        ..constructors.add(
          Constructor(
            (c) => c
              ..constant = true
              ..optionalParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'key'
                    ..named = true
                    ..toSuper = true,
                ),
              )
              ..optionalParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'routeObserver'
                    ..named = true
                    ..toSuper = true,
                ),
              )
              ..optionalParameters.addAll(
                spec.customParameters.map(
                  (p) => p.rebuild((b) => b..toThis = true),
                ),
              ),
          ),
        )
        ..methods.add(
          Method(
            (m) => m
              ..name = 'createState'
              ..annotations.add(refer('override'))
              ..returns = refer('State<${spec.viewName}>')
              ..body = refer(
                '_${spec.viewName}State',
              ).call([]).returned.statement,
          ),
        ),
    );

    final stateClass = Class(
      (c) => c
        ..name = '_${spec.viewName}State'
        ..extend = refer('State<${spec.viewName}>')
        ..methods.add(
          Method(
            (m) => m
              ..name = 'build'
              ..annotations.add(refer('override'))
              ..returns = refer('Widget')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'context'
                    ..type = refer('BuildContext'),
                ),
              )
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer('Scaffold')
                        .newInstance([], {
                          'appBar': refer('AppBar').newInstance([], {
                            'title': refer('Text').newInstance([
                              literalString(spec.entityName ?? spec.viewName),
                            ]),
                          }),
                          'body': refer('Center').newInstance([], {
                            'child': refer('Text').newInstance([
                              literalString('${spec.viewName} is working!'),
                            ]),
                          }),
                        })
                        .returned
                        .statement,
                  ),
              ),
          ),
        ),
    );

    final directives = spec.imports.toSet().map(Directive.import).toList();
    final library = specLibrary.library(
      specs: [viewClass, stateClass],
      directives: directives,
    );

    final emitter = DartEmitter(
      useNullSafetySyntax: true,
      orderDirectives: true,
    );
    var raw = library.accept(emitter).toString();
    if (leadingComment != null) {
      raw = '$leadingComment\n$raw';
    }

    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(raw);
  }

  String _buildCustomView(ViewClassSpec spec) {
    if (spec.isStateful) {
      return _buildCustomStatefulView(spec);
    }
    final viewClass = Class(
      (c) => c
        ..name = spec.viewName
        ..extend = refer('StatelessWidget')
        ..constructors.add(
          Constructor(
            (c) => c
              ..constant = true
              ..optionalParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'key'
                    ..named = true
                    ..toSuper = true,
                ),
              ),
          ),
        )
        ..methods.add(
          Method(
            (m) => m
              ..name = 'build'
              ..annotations.add(refer('override'))
              ..returns = refer('Widget')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'context'
                    ..type = refer('BuildContext'),
                ),
              )
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer('Scaffold')
                        .newInstance([], {
                          'appBar': refer('AppBar').newInstance([], {
                            'title': refer(
                              'Text',
                            ).newInstance([literalString(spec.entityName)]),
                          }),
                          'body': refer('Center').newInstance([], {
                            'child': refer('Text').newInstance([
                              literalString('${spec.viewName} is working!'),
                            ]),
                          }),
                        })
                        .returned
                        .statement,
                  ),
              ),
          ),
        ),
    );

    final directives = spec.imports.toSet().map(Directive.import).toList();
    final library = specLibrary.library(
      specs: [viewClass],
      directives: directives,
    );

    return specLibrary.emitLibrary(library);
  }

  String _buildCustomStatefulView(ViewClassSpec spec) {
    final viewClass = Class(
      (c) => c
        ..name = spec.viewName
        ..extend = refer('StatefulWidget')
        ..constructors.add(
          Constructor(
            (c) => c
              ..constant = true
              ..optionalParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'key'
                    ..named = true
                    ..toSuper = true,
                ),
              ),
          ),
        )
        ..methods.add(
          Method(
            (m) => m
              ..name = 'createState'
              ..annotations.add(refer('override'))
              ..returns = refer('State<${spec.viewName}>')
              ..body = refer(
                '_${spec.viewName}State',
              ).call([]).returned.statement,
          ),
        ),
    );

    final stateClass = Class(
      (c) => c
        ..name = '_${spec.viewName}State'
        ..extend = refer('State<${spec.viewName}>')
        ..methods.add(
          Method(
            (m) => m
              ..name = 'build'
              ..annotations.add(refer('override'))
              ..returns = refer('Widget')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'context'
                    ..type = refer('BuildContext'),
                ),
              )
              ..body = Block(
                (b) => b
                  ..statements.add(
                    refer('Scaffold')
                        .newInstance([], {
                          'appBar': refer('AppBar').newInstance([], {
                            'title': refer(
                              'Text',
                            ).newInstance([literalString(spec.entityName)]),
                          }),
                          'body': refer('Center').newInstance([], {
                            'child': refer('Text').newInstance([
                              literalString('${spec.viewName} is working!'),
                            ]),
                          }),
                        })
                        .returned
                        .statement,
                  ),
              ),
          ),
        ),
    );

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
      customParameters: spec.customParameters,
    );

    final presenterCall = _presenterCall(spec);
    final controllerArgs = <Expression>[presenterCall];
    final controllerNamedArgs = <String, Expression>{};

    if (spec.withState && spec.entityName != null && spec.entityCamel != null) {
      controllerNamedArgs['initial${spec.entityName}'] = refer(
        spec.entityCamel!,
      );
    }

    final controllerCall = refer(
      spec.controllerName,
    ).call(controllerArgs, controllerNamedArgs);

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
        ..fields.addAll(
          spec.customParameters.map(
            (p) => Field(
              (f) => f
                ..name = p.name
                ..type = p.type
                ..modifier = FieldModifier.final$,
            ),
          ),
        )
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
              ..toSuper = true,
          ),
        ),
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
                      'title': refer('Text').constInstance([
                        literalString(spec.entityName ?? spec.viewName),
                      ]),
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
              type: spec.stateClassName != null
                  ? refer(spec.stateClassName!)
                  : null,
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
