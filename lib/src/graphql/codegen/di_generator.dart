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
      b.directives.add(cb.Directive.import('package:graphql/client.dart'));

      // Add relative imports for each datasource and repository
      for (final reg in registrations) {
        final snakeName = _snakeCase(reg.name);
        b.directives.add(
          cb.Directive.import('datasources/${snakeName}_datasource.dart'),
        );
        b.directives.add(
          cb.Directive.import('repositories/${snakeName}_repository.dart'),
        );
      }

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
                final registerMethod = reg.scope == DiScope.transient
                    ? 'registerTransient'
                    : 'registerSingleton';

                // Register datasource
                bl.addExpression(
                  cb
                      .refer('ZuraffaContainer.instance')
                      .property(registerMethod)
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
                      .property(registerMethod)
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

  String _snakeCase(String name) {
    // Handle acronyms and consecutive uppercase letters properly:
    // ProductID -> product_id, SKU -> sku, HTTPRequest -> http_request
    return name
        .replaceAllMapped(
          // Insert underscore before uppercase that follows lowercase or digit,
          // or before the last uppercase in a sequence (e.g., HTTPRequest -> HTTP_Request)
          RegExp(r'([a-z0-9])([A-Z])|([A-Z])([A-Z][a-z])'),
          (m) => m.group(1) != null
              ? '${m.group(1)}_${m.group(2)}'
              : '${m.group(3)}_${m.group(4)}',
        )
        .toLowerCase();
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
