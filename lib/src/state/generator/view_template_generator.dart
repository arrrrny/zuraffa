import 'dart:io';

import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import 'generator_utils.dart';

/// Generates `zfa make`-style view templates using `ControlledWidget`,
/// `FragmentBuilder`, and `SignalBuilder`.
///
/// ```dart
/// final gen = ViewTemplateGenerator(outputDir: 'lib/presentation');
/// gen.generateView('ProductDetail', useCases: ['product', 'reviews']);
/// ```
class ViewTemplateGenerator {
  ViewTemplateGenerator({required this.outputDir});

  final String outputDir;
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  /// Generate a complete view file with ControlledWidget, FragmentBuilder,
  /// and SignalBuilder scaffolding.
  ///
  /// By default the view targets Flutter apps (imports
  /// `package:zuraffa_flutter/zuraffa_flutter.dart` and builds a `Widget`).
  /// With [pureDart] set, the emitted view imports only
  /// `package:zuraffa/zuraffa.dart` and wires fragments through
  /// `ViewContext.attach` — compilable and mountable inside any pure-Dart
  /// host (spec 038 FR-005/SC-003).
  String generateView(
    String name, {
    required List<String> useCases,
    List<String> uiSignals = const ['isLoading', 'activeTabIndex'],
    Map<String, String> uiSignalTypes = const {},
    bool pureDart = false,
  }) {
    final className = '${name}View';
    final presenterName = '${name}Presenter';
    final fileName = '${snakeCase(name)}_view.dart';
    final filePath = p.join(outputDir, fileName);

    final library = cb.Library((b) {
      if (pureDart) {
        b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));
      } else {
        b.directives.add(cb.Directive.import('package:flutter/material.dart'));
        // zuraffa_flutter re-exports zuraffa core AND provides
        // ControlledWidget, FragmentBuilder, and SignalBuilder.
        b.directives.add(
          cb.Directive.import('package:zuraffa_flutter/zuraffa_flutter.dart'),
        );
      }
      b.directives.add(
        cb.Directive.import('${snakeCase(name)}_presenter.dart'),
      );

      b.body.add(
        cb.Class((c) {
          c
            ..name = className
            ..extend = cb.refer('ControlledWidget<$presenterName>')
            ..constructors.add(
              cb.Constructor((ctor) {
                ctor
                  // Flutter views stay `const`-constructible with an optional
                  // key; pure-Dart views have no key concept (no widget tree
                  // identity), so they take only the controller.
                  ..constant = !pureDart
                  // code_builder renders named parameters from
                  // optionalParameters; named entries in requiredParameters
                  // would emit invalid positional syntax.
                  ..optionalParameters.addAll([
                    if (!pureDart)
                      cb.Parameter((p) {
                        p
                          ..name = 'key'
                          ..type = cb.refer('Key?')
                          ..named = true
                          ..toSuper = true;
                      }),
                    cb.Parameter((p) {
                      p
                        ..name = 'controller'
                        ..type = cb.refer(presenterName)
                        ..named = true
                        ..required = true
                        ..toSuper = true;
                    }),
                  ]);
              }),
            );

          // onInit
          c.methods.add(
            cb.Method((m) {
              m
                ..name = 'onInit'
                ..returns = cb.refer('void')
                ..annotations.add(cb.refer('override'))
                ..body = cb.Block((bl) {
                  for (final uc in useCases) {
                    // slice(key) takes the use-case name as its string key;
                    // refresh() on the nullable return is guarded with `?.
                    // Pure-Dart views instead touch the generated late-final
                    // slice FIELD (same name as the slice key): touching it
                    // bootstraps the lazy binding, so the refresh always
                    // reaches a real slice (spec 038 SC-001 — no manual
                    // wiring, no null-assert).
                    bl.statements.add(
                      cb.Code(
                        pureDart
                            ? 'controller.domain.$uc.refresh();'
                            : "controller.domain.slice('$uc')?.refresh();",
                      ),
                    );
                  }
                });
            }),
          );

          // build
          c.methods.add(
            cb.Method((m) {
              m
                ..name = 'build'
                ..returns = cb.refer(pureDart ? 'Object?' : 'Widget')
                ..annotations.add(cb.refer('override'))
                ..requiredParameters.add(
                  cb.Parameter((p) {
                    p
                      ..name = 'context'
                      ..type = cb.refer(
                        pureDart ? 'ViewContext' : 'BuildContext',
                      );
                  }),
                )
                ..body = pureDart
                    ? _pureDartBuildBody(useCases, uiSignals, uiSignalTypes)
                    : cb.Block((bl) {
                        bl.statements.add(cb.Code('return Scaffold('));
                        bl.statements.add(cb.Code('  body: Column('));
                        bl.statements.add(cb.Code('    children: ['));

                        for (final uc in useCases) {
                          bl.statements.add(cb.Code('      // $uc slice'));
                          bl.statements.add(
                            cb.Code('      FragmentBuilder<dynamic>('),
                          );
                          bl.statements.add(
                            cb.Code(
                              "        slice: controller.domain.slice('$uc')!,",
                            ),
                          );
                          bl.statements.add(
                            cb.Code(
                              '        onLoading: (context) => const CircularProgressIndicator(),',
                            ),
                          );
                          bl.statements.add(
                            cb.Code(
                              '        onError: (context, error) => Text(error.message),',
                            ),
                          );
                          bl.statements.add(
                            cb.Code(
                              '        builder: (context, data) => Text(data.toString()),',
                            ),
                          );
                          bl.statements.add(cb.Code('      ),'));
                        }

                        if (uiSignals.isNotEmpty) {
                          bl.statements.add(cb.Code('      // UI signals'));
                          for (final signal in uiSignals) {
                            final type =
                                uiSignalTypes[signal] ??
                                _defaultUiSignalType(signal);
                            bl.statements.add(
                              cb.Code('      SignalBuilder<$type>('),
                            );
                            bl.statements.add(
                              cb.Code(
                                "        signal: controller.view.$signal,",
                              ),
                            );
                            bl.statements.add(
                              cb.Code(
                                '        builder: (context, value) => Text("$signal: \$value"),',
                              ),
                            );
                            bl.statements.add(cb.Code('      ),'));
                          }
                        }

                        bl.statements.add(cb.Code('    ],'));
                        bl.statements.add(cb.Code('  ),'));
                        bl.statements.add(cb.Code(');'));
                      });
            }),
          );
        }),
      );
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    var formatted = raw;
    try {
      formatted = _formatter.format(raw);
    } on FormatterException {
      // Fallback: unformatted code is better than a crash. Narrow the catch
      // to FormatterException so unrelated generator bugs surface instead of
      // silently writing invalid output.
    }

    writeFile(filePath, formatted);
    return filePath;
  }

  /// Default signal types matching the [ViewStateField] defaults used by
  /// [StateGenerator.generateViewState]; unknown signals default to
  /// `dynamic` so `SignalBuilder<dynamic>` remains assignable to any signal.
  static String _defaultUiSignalType(String signal) {
    return switch (signal) {
      'isLoading' => 'bool',
      'activeTabIndex' => 'int',
      _ => 'dynamic',
    };
  }

  /// Builds the `build(ViewContext)` body for pure-Dart generated views:
  /// one `context.attach(FragmentBuilder(...))` per use-case slice and one
  /// `context.attach(SignalBuilder(...))` per UI signal, ending with
  /// `return null;` (the fragments own their outputs — spec 038 FR-005).
  static cb.Block _pureDartBuildBody(
    List<String> useCases,
    List<String> uiSignals,
    Map<String, String> uiSignalTypes,
  ) {
    return cb.Block((bl) {
      for (final uc in useCases) {
        bl.statements.add(cb.Code('      // $uc slice'));
        bl.statements.add(cb.Code('      context.attach('));
        bl.statements.add(cb.Code('        FragmentBuilder<dynamic>('));
        // Typed field access bootstraps the lazy late-final slice field
        // generated by StateGenerator.generateDomainState (field name ==
        // slice key), so the fragment always receives a live slice.
        bl.statements.add(cb.Code('          slice: controller.domain.$uc,'));
        bl.statements.add(
          cb.Code("          onLoading: (context) => '$uc loading',"),
        );
        bl.statements.add(
          cb.Code('          onError: (context, error) => error.message,'),
        );
        bl.statements.add(cb.Code("          onEmpty: (context) => 'no $uc',"));
        bl.statements.add(
          cb.Code('          builder: (context, data) => data.toString(),'),
        );
        bl.statements.add(cb.Code('        ),'));
        bl.statements.add(cb.Code('      );'));
      }

      if (uiSignals.isNotEmpty) {
        bl.statements.add(cb.Code('      // UI signals'));
        for (final signal in uiSignals) {
          final type = uiSignalTypes[signal] ?? _defaultUiSignalType(signal);
          bl.statements.add(cb.Code('      context.attach('));
          bl.statements.add(cb.Code('        SignalBuilder<$type>('));
          bl.statements.add(
            cb.Code('          signal: controller.view.$signal,'),
          );
          bl.statements.add(
            cb.Code(
              '          builder: (context, value) => \'$signal: \$value\',',
            ),
          );
          bl.statements.add(cb.Code('        ),'));
          bl.statements.add(cb.Code('      );'));
        }
      }

      // Fragments own their outputs; the shell itself renders nothing.
      bl.statements.add(cb.Code('      return null;'));
    });
  }

  /// Generate a `{name}Presenter` that extends [DualLayerPresenter],
  /// wiring the generated DomainState and scaffolded ViewState together.
  ///
  /// The presenter is scaffolded once (like ViewState) and is safe for the
  /// developer to extend with orchestration logic. It is **not** regenerated
  /// if it already exists.
  String generatePresenter(
    String name, {
    List<String> useCases = const [],
    bool preserveIfExists = true,
  }) {
    final className = '${name}Presenter';
    final domainClassName = '${name}DomainState';
    final viewClassName = '${name}ViewState';
    final fileName = '${snakeCase(name)}_presenter.dart';
    final filePath = p.join(outputDir, fileName);

    if (preserveIfExists && File(filePath).existsSync()) {
      return filePath;
    }

    final library = cb.Library((b) {
      // #281: v6 Presenter imports 'package:zuraffa_flutter/zuraffa_flutter.dart'
      // (re-exports zuraffa core: DualLayerPresenter/DomainState/ViewState).
      b.directives.add(
        cb.Directive.import('package:zuraffa_flutter/zuraffa_flutter.dart'),
      );
      b.directives.add(
        cb.Directive.import('${snakeCase(name)}_domain_state.dart'),
      );
      b.directives.add(
        cb.Directive.import('${snakeCase(name)}_view_state.dart'),
      );

      b.body.add(
        cb.Class((c) {
          c
            ..name = className
            ..extend = cb.refer('DualLayerPresenter')
            ..constructors.add(
              cb.Constructor((ctor) {
                ctor
                  ..name = null
                  ..initializers.add(
                    cb.Code(
                      'super(domain: $domainClassName(presenter: '
                      'SlicePresenter()), view: $viewClassName())',
                    ),
                  );
              }),
            );
          // Expose a typed SlicePresenter for the DomainState to bind into.
          c.fields.add(
            cb.Field((f) {
              f
                ..name = 'slicePresenter'
                ..modifier = cb.FieldModifier.final$
                ..type = cb.refer('SlicePresenter')
                ..assignment = cb.refer('SlicePresenter').call([]).code;
            }),
          );
          // #281: Override `view` with a covariant return type so the generated
          // view template's `controller.view.<signal>` resolves the concrete
          // {Name}ViewState signals (e.g. isLoading) instead of the base
          // ViewState. The super view is the $viewClassName instance passed to
          // super above, so the cast is always safe.
          c.methods.add(
            cb.Method((m) {
              m
                ..name = 'view'
                ..type = cb.MethodType.getter
                ..returns = cb.refer(viewClassName)
                ..annotations.add(cb.refer('override'))
                ..body = cb.Code('=> super.view as $viewClassName;');
            }),
          );
          // Spec 038 (FR-005): mirror the `view` override for `domain` so
          // generated views can use typed slice field access
          // (`controller.domain.<sliceKey>`), which also bootstraps the lazy
          // late-final slice fields emitted by generateDomainState. The
          // super domain is the $domainClassName instance passed to super
          // above, so the cast is always safe.
          c.methods.add(
            cb.Method((m) {
              m
                ..name = 'domain'
                ..type = cb.MethodType.getter
                ..returns = cb.refer(domainClassName)
                ..annotations.add(cb.refer('override'))
                ..body = cb.Code('=> super.domain as $domainClassName;');
            }),
          );
        }),
      );
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    var formatted = raw;
    try {
      formatted = _formatter.format(raw);
    } on FormatterException {
      // Fallback: unformatted code is better than a crash.
    }

    writeFile(filePath, formatted);
    return filePath;
  }
}
