/// DiGraphCheck (feature 074, issue #962): the merge-time DI proof —
/// a generated conformance test constructs the merged host's service
/// locator with the feature's binding module registered (flavor-
/// switched: mock and real) and resolves EVERY manifest token per
/// flavor. Evidence, not grep.
///
/// Pure: token/flavor facts in, generated test + offenders out. The
/// actual construction runs through the host's suite runner (injectable
/// seam); the bootstrap smoke pattern is the proven shape.
library;

import '../generators/_pascal_case.dart';

/// One declared DI binding of the feature.
class DiBindingDecl {
  final String token;

  /// Flavors that must resolve this token (e.g. `mock`, `real`).
  final List<String> flavors;

  /// The binding module that must register the token.
  final String module;

  const DiBindingDecl({
    required this.token,
    required this.flavors,
    this.module = 'feature',
  });
}

/// The generated DI graph proof.
abstract final class DiGraphCheck {
  /// Generate the conformance test the merged host runs: constructs
  /// the locator with the feature's binding module registered, then
  /// resolves every declared token per flavor (bootstrap smoke shape).
  static String conformanceTestSource({
    required String feature,
    required String bindingModule,
    required List<DiBindingDecl> bindings,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        '// GENERATED — DI graph conformance (feature $feature, issue #962).',
      )
      ..writeln("// Proves the merged host's graph constructs: every")
      ..writeln('// declared token resolves in every declared flavor.')
      ..writeln("import 'package:test/test.dart';")
      ..writeln("import 'package:zuraffa/$bindingModule';")
      ..writeln()
      ..writeln('void main() {')
      ..writeln("  group('DI graph constructs ($feature)', () {");
    for (final binding in bindings) {
      for (final flavor in binding.flavors) {
        buffer
          ..writeln(
            "    test('${binding.token} resolves (flavor: $flavor)', () {",
          )
          ..writeln('      final graph = DiGraph(flavor: \'$flavor\');')
          ..writeln("      graph.register${pascalCase(feature)}Bindings();")
          ..writeln(
            "      expect(graph.resolve('${binding.token}'), isNotNull);",
          )
          ..writeln('    });');
      }
    }
    buffer
      ..writeln('  });')
      ..writeln('}');
    return buffer.toString();
  }

  /// The resolution check over construction results: every declared
  /// token must resolve in every declared flavor. Offenders name the
  /// token AND the flavor, with the fix hint.
  static List<String> resolutionOffenders({
    required List<DiBindingDecl> bindings,
    required bool Function(String token, String flavor) resolves,
  }) {
    return [
      for (final binding in bindings)
        for (final flavor in binding.flavors)
          if (!resolves(binding.token, flavor))
            "DI token '${binding.token}' (flavor: $flavor) did not resolve "
                'after merge --> fix: register ${binding.token} in the '
                "feature's binding module (lib/src/di/${binding.module}"
                '_binding.dart), then re-run `zfa slice merge --into <host>`.',
    ];
  }
}

