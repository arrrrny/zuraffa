import 'dart:io';
import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

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
  String generateView(
    String name, {
    required List<String> useCases,
    List<String> uiSignals = const ['isLoading', 'activeTabIndex'],
  }) {
    final className = '${name}View';
    final presenterName = '${name}Presenter';
    final fileName = '${_snakeCase(name)}_view.dart';
    final filePath = p.join(outputDir, fileName);

    final library = cb.Library((b) {
      b.directives.add(cb.Directive.import('package:flutter/material.dart'));
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));
      b.directives.add(
        cb.Directive.import('${_snakeCase(name)}_presenter.dart'),
      );

      b.body.add(
        cb.Class((c) {
          c
            ..name = className
            ..extend = cb.refer('ControlledWidget<$presenterName>')
            ..constructors.add(
              cb.Constructor((ctor) {
                ctor
                  ..constant = true
                  ..requiredParameters.add(
                    cb.Parameter((p) {
                      p
                        ..name = 'key'
                        ..type = cb.refer('Key?')
                        ..named = true
                        ..toSuper = true;
                    }),
                  )
                  ..requiredParameters.add(
                    cb.Parameter((p) {
                      p
                        ..name = 'controller'
                        ..type = cb.refer(presenterName)
                        ..named = true
                        ..toSuper = true;
                    }),
                  );
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
                    bl.addExpression(
                      cb
                          .refer('controller.domain.slice')
                          .call([], {}, [cb.refer('dynamic')])
                          .property(uc)
                          .property('refresh')
                          .call([]),
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
                ..returns = cb.refer('Widget')
                ..annotations.add(cb.refer('override'))
                ..requiredParameters.add(
                  cb.Parameter((p) {
                    p
                      ..name = 'context'
                      ..type = cb.refer('BuildContext');
                  }),
                )
                ..body = cb.Block((bl) {
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
                      bl.statements.add(cb.Code('      SignalBuilder<bool>('));
                      bl.statements.add(
                        cb.Code("        signal: controller.view.$signal,"),
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
    } on Exception {
      // Fallback: unformatted code is better than a crash.
    }

    _writeFile(filePath, formatted);
    return filePath;
  }

  void _writeFile(String path, String content) {
    final file = File(path);
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String _snakeCase(String name) {
    return name
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => '_${m.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }
}
