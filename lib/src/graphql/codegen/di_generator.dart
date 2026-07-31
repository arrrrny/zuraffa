import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';

/// Generates DI registration code for datasources and repositories.
///
/// ```dart
/// final gen = DiGenerator();
/// final code = gen.generate([
///   DiRegistration(name: 'Product', scope: DiScope.singleton),
/// ]);
/// ```
class DiGenerator {
  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  String generate(List<DiRegistration> registrations) {
    final library = cb.Library((b) {
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));

      b.body.add(
        cb.Method((m) {
          m
            ..name = 'configureGraphqlDi'
            ..returns = cb.refer('void')
            ..body = cb.Block((bl) {
              for (final reg in registrations) {
                final datasourceType = '\$${reg.name}Datasource';
                final repoInterface = '${reg.name}Repository';
                final repoImpl = '${reg.name}RepositoryImpl';

                // Register datasource
                bl.addExpression(
                  cb
                      .refer('ZuraffaContainer.instance')
                      .property('registerSingleton')
                      .call(
                        [
                          cb.Method(
                            (mm) => mm
                              ..body = cb.refer(datasourceType).call([
                                cb
                                    .refer('ZuraffaContainer.instance')
                                    .property('resolve')
                                    .call([], {}, [cb.refer('GraphQLClient')]),
                              ]).code,
                          ).closure,
                        ],
                        {},
                        [cb.refer(datasourceType)],
                      ),
                );

                // Register repository
                bl.addExpression(
                  cb
                      .refer('ZuraffaContainer.instance')
                      .property('registerSingleton')
                      .call(
                        [
                          cb.Method(
                            (mm) => mm
                              ..body = cb.refer(repoImpl).call([
                                cb
                                    .refer('ZuraffaContainer.instance')
                                    .property('resolve')
                                    .call([], {}, [cb.refer(datasourceType)]),
                              ]).code,
                          ).closure,
                        ],
                        {},
                        [cb.refer(repoInterface)],
                      ),
                );
              }
            });
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
    return formatted;
  }
}

/// A single DI registration for a generated datasource + repository pair.
class DiRegistration {
  DiRegistration({required this.name, this.scope = DiScope.singleton});
  final String name;
  final DiScope scope;
}

/// Lifecycle scope for a generated registration.
enum DiScope { singleton, transient }
