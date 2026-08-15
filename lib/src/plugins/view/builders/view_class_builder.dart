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
  final bool withXRay;
  // #359: when non-null, the view body renders the entity's mock data
  // (a ListView over <Entity>MockData.sampleList for list views, a Card
  // with <Entity>MockData.sample<Entity> for detail views) instead of
  // the empty Container(). Null means the mock data file is not (yet)
  // present on disk — the view falls back to Container() with a TODO.
  final String? mockDataImportPath;

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
    this.withXRay = false,
    this.stateClassName,
    this.mockDataImportPath,
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

  /// Parses an import string, honoring an optional trailing
  /// `hide Symbol1, Symbol2` combinator so callers can disambiguate entity
  /// names that collide with Flutter symbols (#337).
  static Directive _parseImport(String import) {
    final match = RegExp('^(.*)\\s+hide\\s+(.+)\$').firstMatch(import);
    if (match == null) {
      return Directive.import(import);
    }
    return Directive(
      (d) => d
        ..type = DirectiveType.import
        ..url = match.group(1)!.trim()
        ..hide.addAll(
          match.group(2)!.split(',').map((s) => s.trim()),
        ),
    );
  }

  String build(ViewClassSpec spec, {String? leadingComment}) {
    if (spec.isCustom) {
      return _buildCustomView(spec, leadingComment: leadingComment);
    }
    final viewClass = _buildViewClass(spec);
    final stateClass = _buildStateClass(spec);
    final directives = spec.imports.toSet().map(_parseImport).toList();

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

    var formatted = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(raw);

    if (spec.withXRay) {
      final enumRaw = 'enum ${spec.viewName}Node { body }';
      final enumFormatted = DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(enumRaw);
      formatted = '$formatted\n$enumFormatted';
    }

    return formatted;
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
              // #343: plain StatefulWidget/StatelessWidget have no
              // routeObserver constructor param; forwarding it produced
              // super_formal_parameter_without_associated_named. Only
              // entity-backed CleanView views accept routeObserver.
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

    final directives = spec.imports.toSet().map(_parseImport).toList();
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
              // #343: plain StatefulWidget/StatelessWidget have no
              // routeObserver constructor param; forwarding it produced
              // super_formal_parameter_without_associated_named. Only
              // entity-backed CleanView views accept routeObserver.
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

    final directives = spec.imports.toSet().map(_parseImport).toList();
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

    final scaffoldWidget = refer('Scaffold').call([], {
      'key': refer('globalKey'),
      'appBar': refer('AppBar').call([], {
        'title': refer(
          'Text',
        ).constInstance([literalString(spec.entityName ?? spec.viewName)]),
      }),
      'body': refer(
        'ControlledWidgetBuilder<${spec.controllerName}>',
      ).call([], {'builder': builderClosure}),
    });

    final viewGetter = Method(
      (m) => m
        ..name = 'view'
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..returns = refer('Widget')
        ..body = Block(
          (b) => b
            ..statements.add(
              (spec.withXRay
                      ? refer('XRayScope').call([], {
                          'viewId': literalString(spec.viewName),
                          'child': scaffoldWidget,
                        })
                      : scaffoldWidget)
                  .returned
                  .statement,
            ),
        ),
    );

    final stateType = spec.withState && spec.stateClassName != null
        ? spec.stateClassName!
        : 'void';

    return Class(
      (c) => c
        ..name = '_${spec.viewName}State'
        ..extend = refer(
          'CleanViewState<${spec.viewName}, ${spec.controllerName}, $stateType>',
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
    // Build the inner widget expression based on withState
    final Expression innerWidget;
    final List<Code> stateDeclarations = [];

    // #359: when mock data is available, render a real list/detail of
    // entities instead of the empty Container(). The body consumes
    // <Entity>MockData.sampleList (list views) or <Entity>MockData
    // .sample<Entity> (detail views) — so a freshly generated app is
    // visibly functional out of the box. The presenter/controller are
    // still wired (the user can swap the mock list for
    // controller.viewState once the state contract is shaped).
    final mockAvailable = spec.mockDataImportPath != null &&
        spec.entityName != null &&
        !spec.isCustom;

    if (spec.withState) {
      // Declare viewState variable (still useful for the user's future
      // state-driven rendering; we don't reference it here to avoid an
      // unused warning, but the declaration stays so swapping the body
      // is a one-line change).
      stateDeclarations.add(
        declareFinal(
          'viewState',
          type: spec.stateClassName != null
              ? refer(spec.stateClassName!)
              : null,
        ).assign(refer('controller').property('viewState')).statement,
      );
    }

    if (mockAvailable) {
      innerWidget = _buildMockDataWidget(spec);
    } else if (spec.withState) {
      // State-aware Container with ValueKey
      innerWidget = refer('Container').call([], {
        'key': refer(
          'ValueKey',
        ).call([refer('viewState').property('hashCode')]),
      });
    } else {
      // Plain Container (mock data not generated yet — fallback).
      innerWidget = refer('Container').call([]);
    }

    // Wrap in XRayNode if enabled
    final Expression returnedWidget = spec.withXRay
        ? refer('XRayNode<${spec.viewName}Node>').call([], {
            'nodeId': refer('${spec.viewName}Node.body'),
            'child': innerWidget,
          })
        : innerWidget;

    return Block(
      (b) => b
        ..statements.addAll(stateDeclarations)
        ..statements.add(returnedWidget.returned.statement),
    );
  }

  /// #359: Builds the mock-data-backed widget for the view body.
  ///
  /// - List views (view name does NOT end with `DetailView`):
  ///   `ListView.builder(itemCount: <Entity>MockData.sampleList.length,
  ///    itemBuilder: (ctx, i) => ListTile(title: Text(item.toString()),
  ///    subtitle: Text('Mock #...')))`
  /// - Detail views (view name ends with `DetailView`):
  ///   `Center(child: Card(child: ListTile(title: Text('<Entity> detail'),
  ///    subtitle: Text(<Entity>MockData.sample<Entity>.toString()))))`
  Expression _buildMockDataWidget(ViewClassSpec spec) {
    final entity = spec.entityName!;
    final mockRef = refer('${entity}MockData');

    if (spec.viewName.endsWith('DetailView')) {
      final sampleGetter = 'sample$entity';
      return refer('Center').call([], {
        'child': refer('Card').call([], {
          'child': refer('ListTile').call([], {
            'title': refer('Text').call([
              literalString('$entity detail'),
            ]),
            'subtitle': refer('Text').call([
              mockRef.property(sampleGetter).property('toString').call([]),
            ]),
          }),
        }),
      });
    }

    // List view
    final sampleList = mockRef.property('sampleList');
    return refer('ListView').property('builder').call([], {
      'itemCount': sampleList.property('length'),
      'itemBuilder': Method(
        (m) => m
          ..requiredParameters.addAll([
            Parameter((p) => p..name = 'context'),
            Parameter((p) => p..name = 'index'),
          ])
          ..lambda = true
          ..body = refer('ListTile').call([], {
            'title': refer('Text').call([
              sampleList.index(refer('index')).property('toString').call([]),
            ]),
            'subtitle': refer('Text').call([
              CodeExpression(Code(r"'Mock #${index + 1}'")),
            ]),
          }).code,
      ).closure,
    });
  }
}
