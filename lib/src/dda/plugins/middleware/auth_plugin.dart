import '../../compiler/zorphy_decorator_plugin.dart';
import '../../models/decorator_ast.dart';
import '../../models/zorphy_context.dart';
import 'middleware_annotation.dart';
import 'auth_generator.dart';

/// DDA plugin that processes `@RequiresAuth` annotations on UseCase
/// classes or methods and generates security interceptor logic.
///
/// This plugin is registered automatically when `zfa build` runs.
/// After the build, call [generateAuthFile] to emit
/// `lib/src/middleware/zfa_auth.g.dart`.
///
/// Supported annotations:
/// - `@RequiresAuth(Role.admin)` — single-role authorization
/// - `@RequiresAuth(roles: [Role.admin, Role.manager], mode: AuthorizationMode.any)`
///
/// The generated interceptor checks user roles before UseCase execution.
/// Unauthorized calls emit `AppFailure.session` without executing the UseCase.
class AuthDDAPlugin extends ZorphyDecoratorPlugin {
  AuthDDAPlugin({this.packageName = 'zuraffa'});

  /// The package name used to build import URIs.
  final String packageName;

  late final _generator = AuthGenerator();

  @override
  String get targetDecorator => 'RequiresAuth';

  @override
  List<String> get targetDecorators => const ['RequiresAuth'];

  @override
  int get priority => 2;

  @override
  void onApply(
    MethodAST method,
    DecoratorAST decorator,
    ZorphyContext context,
  ) {
    final className = method.className ?? '';
    final methodName = method.name;
    final importUri = _extractImportUri(method.libraryUri);
    final returnType = method.returnType ?? 'dynamic';
    final params = method.parameters;

    // Parse roles from annotation
    final roles = _parseRoles(decorator);
    final mode = _parseMode(decorator);

    _generator.addAuthEntry(
      className: className,
      methodName: methodName,
      importUri: importUri,
      returnType: returnType,
      parameters: params,
      roles: roles,
      mode: mode,
      isClassLevel: method.isClass,
    );
  }

  /// Generate the auth middleware file content.
  String generateAuthFile() => _generator.generate();

  /// Whether any auth entries were collected.
  bool get hasAuthEntries => _generator.hasEntries;

  // -- Helpers --

  String _extractImportUri(String? libraryUri) {
    if (libraryUri == null) return '';
    if (libraryUri.contains('/lib/')) {
      final parts = libraryUri.split('/lib/');
      if (parts.length == 2) {
        return 'package:$packageName/${parts[1]}';
      }
    }
    return libraryUri;
  }

  List<String> _parseRoles(DecoratorAST decorator) {
    // Check for single `role` parameter
    final singleRole = decorator.get<String>('role');
    if (singleRole != null) {
      // Extract role name from string like 'Role.admin' or just 'admin'
      final name = singleRole.contains('.')
          ? singleRole.split('.').last
          : singleRole;
      return [name];
    }

    // Check for `roles` list parameter
    final rolesRaw = decorator.get<List>('roles');
    if (rolesRaw != null) {
      return rolesRaw.map((r) {
        final s = r.toString();
        return s.contains('.') ? s.split('.').last : s;
      }).toList();
    }

    return const [];
  }

  AuthorizationMode _parseMode(DecoratorAST decorator) {
    final modeStr = decorator.get<String>('mode');
    if (modeStr == null) return AuthorizationMode.all;
    final normalized = modeStr.trim().split('.').last;
    switch (normalized) {
      case 'any':
        return AuthorizationMode.any;
      case 'all':
      default:
        return AuthorizationMode.all;
    }
  }
}
