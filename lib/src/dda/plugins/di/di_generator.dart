import 'package:code_builder/code_builder.dart' as cb;
import 'package:dart_style/dart_style.dart';

/// Generates `lib/src/di/zuraffa_injection.g.dart` from collected
/// @Datasource and @Repository metadata.
class DIGenerator {
  DIGenerator({this.targetEnv = '*'});

  final String targetEnv;

  static final _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  final List<_DiRegistration> _datasources = [];
  final List<_DiRegistration> _repositories = [];

  bool get hasRegistrations =>
      _datasources.isNotEmpty || _repositories.isNotEmpty;

  void addDatasource({
    required String className,
    required String importUri,
    String? interfaceName,
    required String scope,
    required List<String> env,
    required List<ConstructorParam> constructorParams,
  }) {
    if (!_matchesEnv(env)) return;
    _datasources.add(
      _DiRegistration(
        className: className,
        importUri: importUri,
        interfaceName: interfaceName,
        scope: scope,
        constructorParams: constructorParams,
      ),
    );
  }

  void addRepository({
    required String className,
    required String importUri,
    String? interfaceName,
    required List<ConstructorParam> constructorParams,
  }) {
    _repositories.add(
      _DiRegistration(
        className: className,
        importUri: importUri,
        interfaceName: interfaceName,
        scope: 'singleton',
        constructorParams: constructorParams,
      ),
    );
  }

  bool _matchesEnv(List<String> env) {
    return env.contains('*') || env.contains(targetEnv);
  }

  String generate() {
    final library = cb.Library((b) {
      b.generatedByComment = 'zfa DDA pipeline';

      final allImports = <String>{};
      for (final reg in [..._datasources, ..._repositories]) {
        allImports.add(reg.importUri);
      }
      b.directives.add(cb.Directive.import('package:zuraffa/zuraffa.dart'));
      for (final uri in allImports) {
        b.directives.add(cb.Directive.import(uri));
      }

      b.body.add(
        cb.Method((m) {
          m
            ..name = 'configureZuraffaInjections'
            ..returns = cb.refer('void')
            ..body = cb.Block((bl) {
              for (final reg in _datasources) {
                bl.addExpression(_buildRegistration(reg));
              }
              for (final reg in _repositories) {
                bl.addExpression(_buildRegistration(reg));
              }
            });
        }),
      );
    });

    final emitter = cb.DartEmitter();
    final raw = library.accept(emitter).toString();
    return _formatter.format(raw);
  }

  cb.Expression _buildRegistration(_DiRegistration reg) {
    final classRef = cb.refer(reg.className);
    final interfaceRef = reg.interfaceName != null
        ? cb.refer(reg.interfaceName!)
        : classRef;

    final namedArgs = <String, cb.Expression>{};
    for (final param in reg.constructorParams) {
      if (param.isNamed) {
        namedArgs[param.name] = cb.refer('container').property('resolve').call(
          [],
          {},
          [cb.refer(param.type)],
        );
      }
    }

    final positionalArgs = reg.constructorParams
        .where((p) => !p.isNamed)
        .map(
          (p) => cb.refer('container').property('resolve').call([], {}, [
            cb.refer(p.type),
          ]),
        )
        .toList();

    final instanceCreation = classRef.call(positionalArgs, namedArgs);

    final registerMethod = reg.scope == 'singleton'
        ? 'registerSingleton'
        : reg.scope == 'lazy'
        ? 'registerLazySingleton'
        : 'registerFactory';

    return cb
        .refer('ZuraffaContainer.instance')
        .property(registerMethod)
        .call(
          [cb.Method((m) => m..body = instanceCreation.code).closure],
          {},
          [interfaceRef],
        );
  }
}

class _DiRegistration {
  _DiRegistration({
    required this.className,
    required this.importUri,
    this.interfaceName,
    required this.scope,
    required this.constructorParams,
  });

  final String className;
  final String importUri;
  final String? interfaceName;
  final String scope;
  final List<ConstructorParam> constructorParams;
}

class ConstructorParam {
  ConstructorParam({
    required this.name,
    required this.type,
    this.isNamed = false,
  });

  final String name;
  final String type;
  final bool isNamed;
}
