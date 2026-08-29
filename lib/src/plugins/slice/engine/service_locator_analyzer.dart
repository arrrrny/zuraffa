/// ServiceLocatorAnalyzer (spec 043): `getIt<T>()` extraction (FR-001).
///
/// Syntactic-only detection (research R-002): a service-locator lookup is a
/// method invocation named `getIt` (or a `getIt`-bound property such as
/// `GetIt.instance`) carrying an explicit type argument. Nested calls like
/// `registerUseCase(getIt<T>())` are found by visiting every invocation in
/// the unit (U10); unrelated generic calls are ignored (U11).
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import '../../../core/ast/file_parser.dart';
import '../../../utils/string_utils.dart';

/// Extracts service-locator type lookups and maps them to DI files.
class ServiceLocatorAnalyzer {
  /// Creates the analyzer with an optional [parser] (injectable for tests).
  ServiceLocatorAnalyzer({FileParser? parser}) : _parser = parser ?? const FileParser();

  final FileParser _parser;

  /// Extracts every `getIt<T>()` type name from [source].
  ///
  /// Duplicates are removed while preserving first-seen order.
  List<String> extractServiceLocatorTypes(String source) {
    final result = _parser.parseSource(source);
    final unit = result.unit;
    if (unit == null) return const [];
    final visitor = _ServiceLocatorVisitor();
    unit.accept(visitor);
    return visitor.types.toList();
  }

  /// Maps [typeName] to its DI registration file under
  /// `<projectRoot>/lib/src/di/` (snake_case naming), or null when no file
  /// matches (U12).
  ///
  /// The Zuraffa DI convention is `<snake_case_type>_di.dart` anywhere under
  /// `lib/src/di/` (e.g. `GetProductUseCase` ->
  /// `lib/src/di/usecases/get_product_usecase_di.dart`).
  String? diRegistrationFileFor(String typeName, String projectRoot) {
    final diRoot = Directory(p.join(projectRoot, 'lib', 'src', 'di'));
    if (!diRoot.existsSync()) return null;
    final expected = '${_registrationSnake(typeName)}_di.dart';
    final matches = diRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.basename(file.path) == expected)
        .toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => a.path.compareTo(b.path));
    return p.canonicalize(matches.first.path);
  }

  /// The Zuraffa DI naming convention: `GetProductUseCase` maps to
  /// `get_product_usecase` (the `UseCase` suffix is one word, matching how
  /// the DI plugin emits `${snake}_usecase_di.dart`); anything else maps
  /// through plain camelCase-to-snake_case.
  static String _registrationSnake(String typeName) {
    if (typeName.endsWith('UseCase')) {
      final base = typeName.substring(0, typeName.length - 'UseCase'.length);
      return '${StringUtils.camelToSnake(base)}_usecase';
    }
    return StringUtils.camelToSnake(typeName);
  }
}

/// AST visitor collecting type arguments of `getIt`-shaped invocations.
class _ServiceLocatorVisitor extends RecursiveAstVisitor<void> {
  final List<String> types = <String>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isGetItLookup(node)) {
      final typeArgs = node.typeArguments?.arguments ?? const <TypeAnnotation>[];
      if (typeArgs.length == 1) {
        final name = typeArgs.first.toString();
        if (!types.contains(name)) {
          types.add(name);
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  /// `getIt<T>()`, `getIt.get<T>()`, `GetIt.instance<T>()`, `GetIt.I<T>()`.
  ///
  /// A bare `getIt<T>()` invocation carries a null target — the identifier
  /// itself is the callee — so the direct case must not demand a target.
  bool _isGetItLookup(MethodInvocation node) {
    if (node.typeArguments == null) return false;
    final method = node.methodName.token.lexeme;
    final target = node.target;
    if (method == 'getIt' && (target == null || _targetIsGetItBinding(target))) {
      return true;
    }
    if (target != null && _targetIsGetItBinding(target)) {
      return method == 'instance' || method == 'get' || method == 'call';
    }
    if ((method == 'get' || method == 'call') &&
        target != null &&
        _targetIsGetItVariable(target)) {
      return true;
    }
    return false;
  }

  /// Targets rooted at the `GetIt` class: `GetIt`, `GetIt.instance`,
  /// `GetIt.I`.
  bool _targetIsGetItBinding(Expression target) {
    if (target is SimpleIdentifier) {
      return target.token.lexeme == 'GetIt';
    }
    if (target is PrefixedIdentifier) {
      return target.prefix.token.lexeme == 'GetIt' &&
          (target.identifier.token.lexeme == 'instance' ||
              target.identifier.token.lexeme == 'I');
    }
    if (target is PropertyAccess) {
      final propertyTarget = target.target;
      return propertyTarget != null &&
          _targetIsGetItBinding(propertyTarget);
    }
    return false;
  }

  /// Targets rooted at a `getIt` variable: `getIt`, `getIt.x`.
  bool _targetIsGetItVariable(Expression target) {
    if (target is SimpleIdentifier) {
      return target.token.lexeme == 'getIt';
    }
    if (target is PropertyAccess) {
      final propertyTarget = target.target;
      return propertyTarget != null &&
          _targetIsGetItVariable(propertyTarget);
    }
    return false;
  }
}
