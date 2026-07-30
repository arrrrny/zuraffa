import '../../compiler/zorphy_decorator_plugin.dart';
import '../../models/decorator_ast.dart';
import '../../models/zorphy_context.dart';
import 'di_generator.dart';

/// DDA plugin that processes `@Datasource` and `@Repository` annotations
/// and accumulates DI registration metadata.
///
/// This plugin is registered automatically when `zfa build` runs.
/// After the build, call [generateInjectionFile] to emit
/// `lib/src/di/zuraffa_injection.g.dart`.
class DIPlugin extends ZorphyDecoratorPlugin {
  DIPlugin({this.targetEnv = '*'});

  final String targetEnv;
  final _generator = DIGenerator();

  @override
  String get targetDecorator => 'Datasource'; // Also handles Repository via onApply

  @override
  void onApply(
    MethodAST method,
    DecoratorAST decorator,
    ZorphyContext context,
  ) {
    if (method.elementKind != 'class') return;

    final className = method.name;
    final importUri = _extractImportUri(method.libraryUri);
    final interfaceName = _extractInterface(method);
    final constructorParams = _extractConstructorParams(method);

    if (decorator.name == 'Datasource') {
      decorator.get<String>('name') ?? className;
      final scopeStr = decorator.get<String>('scope') ?? 'singleton';
      final env = _parseEnv(decorator.get<dynamic>('env'));

      _generator.addDatasource(
        className: className,
        importUri: importUri,
        interfaceName: interfaceName,
        scope: scopeStr,
        env: env,
        constructorParams: constructorParams,
      );
    } else if (decorator.name == 'Repository') {
      decorator.get<String>('name') ?? className;

      _generator.addRepository(
        className: className,
        importUri: importUri,
        interfaceName: interfaceName,
        constructorParams: constructorParams,
      );
    }
  }

  /// Generate the DI registration file content.
  String generateInjectionFile() => _generator.generate();

  /// Whether any registrations were collected.
  bool get hasRegistrations => _generator.hasRegistrations;

  // ── Helpers ──

  String _extractImportUri(String? libraryUri) {
    if (libraryUri == null) return '';
    if (libraryUri.contains('/lib/')) {
      final parts = libraryUri.split('/lib/');
      if (parts.length == 2) {
        return 'package:zuraffa/${parts[1]}';
      }
    }
    return libraryUri;
  }

  String? _extractInterface(MethodAST method) {
    if (method.interfaces.isNotEmpty) {
      return method.interfaces.first;
    }
    if (method.superclassName != null && method.superclassName != 'Object') {
      return method.superclassName;
    }
    return null;
  }

  List<ConstructorParam> _extractConstructorParams(MethodAST method) {
    return method.parameters
        .map(
          (p) =>
              ConstructorParam(name: p.name, type: p.type, isNamed: p.isNamed),
        )
        .toList();
  }

  List<String> _parseEnv(dynamic envValue) {
    if (envValue == null) return const ['*'];
    if (envValue is List) return envValue.cast<String>();
    if (envValue is String) return [envValue];
    return const ['*'];
  }
}
