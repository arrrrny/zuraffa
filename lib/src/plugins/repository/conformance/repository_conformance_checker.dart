import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/file_parser.dart';
import '../../../models/generator_config.dart';

/// Spec 0973 (issue #973) — generation-time interface↔impl conformance gate
/// for the repository plugin.
///
/// After the plugin emits an interface/implementation pair, this checker
/// parses both files **in-process** (analyzer AST, no build step) and proves
/// the pair conforms:
///
///   * every interface method has an implementation member, and
///   * every implementation member that claims the interface (directly or
///     through an `@override` annotation) corresponds to an interface method.
///
/// The verdict is [ConformanceResult]; a failing verdict is reported with a
/// per-method failure list and a `--> fix:` line naming the method and the
/// side that must change. [RepositoryConformanceException] carries the
/// verdict out of generation so the CLI exits non-zero (issue #973: "it
/// compiles and conforms" must be a proven claim, not an assumption
/// verified downstream by `zfa build`).
class ConformanceFailure {
  /// Method the finding is about.
  final String method;

  /// Which side must change: `interface` or `implementation`.
  final String side;

  /// Single-line human explanation.
  final String message;

  /// Actionable `--> fix:` line naming the method and side.
  final String fix;

  const ConformanceFailure({
    required this.method,
    required this.side,
    required this.message,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
    'method': method,
    'side': side,
    'message': message,
    'fix': fix,
  };

  @override
  String toString() => '$message\n    $fix';
}

class ConformanceResult {
  final bool ok;
  final String interfaceClass;
  final String implementationClass;

  /// Methods declared on the interface (declaration order).
  final List<String> interfaceMethods;

  /// Implementation members annotated `@override`.
  final List<String> implementationOverrides;
  final List<ConformanceFailure> failures;

  const ConformanceResult({
    required this.ok,
    required this.interfaceClass,
    required this.implementationClass,
    required this.interfaceMethods,
    required this.implementationOverrides,
    required this.failures,
  });

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'interface_class': interfaceClass,
    'implementation_class': implementationClass,
    'interface_methods': interfaceMethods,
    'implementation_overrides': implementationOverrides,
    'failures': failures.map((f) => f.toJson()).toList(),
  };
}

class RepositoryConformanceChecker {
  const RepositoryConformanceChecker();

  /// Audits [interfaceSource] against [implementationSource].
  ///
  /// [requiredInterfaceMethods] narrows the audit to the methods the current
  /// run contributed (append flows assert their own additions, not
  /// pre-existing members). An empty set audits **every** interface method —
  /// the strongest claim, used when the pair was freshly emitted.
  ///
  /// [auditedImplementationMethods] mirrors that narrowing for the
  /// vice-versa direction (impl `@override` members with no interface
  /// declaration). An empty set audits every `@override` member.
  ConformanceResult check({
    required String interfaceSource,
    required String implementationSource,
    required String interfaceClassName,
    required String implementationClassName,
    Set<String> requiredInterfaceMethods = const {},
    Set<String> auditedImplementationMethods = const {},
  }) {
    final failures = <ConformanceFailure>[];

    final interfaceMethods = _parseMembers(interfaceSource, interfaceClassName);
    final implMembers = _parseMembers(
      implementationSource,
      implementationClassName,
    );

    final interfaceNames = interfaceMethods.keys.toList();
    final overrideNames = implMembers.entries
        .where((e) => e.value.hasOverride)
        .map((e) => e.key)
        .toList();

    // Direction 1: every required interface method has an implementing
    // member with `@override`.
    final required = requiredInterfaceMethods.isEmpty
        ? interfaceNames.toSet()
        : requiredInterfaceMethods;
    for (final name in required) {
      if (!interfaceMethods.containsKey(name)) {
        // Required set names a method the interface does not declare —
        // nothing to conform to (an unknown --methods verb contributes
        // nothing to the interface). The impl-side direction below catches
        // the orphaned override.
        continue;
      }
      final member = implMembers[name];
      if (member == null) {
        failures.add(
          ConformanceFailure(
            method: name,
            side: 'implementation',
            message:
                'interface method `$name` declared on $interfaceClassName '
                'has no implementation in $implementationClassName',
            fix:
                "--> fix: implement '$name' on the implementation side "
                '($implementationClassName) — $interfaceClassName declares '
                'it without an overriding member.',
          ),
        );
      } else if (!member.hasOverride) {
        failures.add(
          ConformanceFailure(
            method: name,
            side: 'implementation',
            message:
                'implementation of `$name` in $implementationClassName is '
                'missing @override (it claims $interfaceClassName)',
            fix:
                "--> fix: add @override to '$name' on the implementation "
                'side ($implementationClassName).',
          ),
        );
      }
    }

    // Direction 2 (vice versa): every audited impl `@override` member
    // corresponds to an interface method.
    final audited = auditedImplementationMethods.isEmpty
        ? overrideNames.toSet()
        : auditedImplementationMethods;
    for (final name in audited) {
      if (!implMembers.containsKey(name)) continue;
      if (!implMembers[name]!.hasOverride) continue;
      if (interfaceMethods.containsKey(name)) continue;
      failures.add(
        ConformanceFailure(
          method: name,
          side: 'interface',
          message:
              'implementation method `$name` carries @override but is not '
              'declared on $interfaceClassName '
              '(override_on_non_overriding_member)',
          fix:
              "--> fix: remove @override '$name' from the implementation "
              'side ($implementationClassName) or declare it on the '
              'interface side ($interfaceClassName).',
        ),
      );
    }

    failures.sort((a, b) {
      final bySide = a.side.compareTo(b.side);
      return bySide != 0 ? bySide : a.method.compareTo(b.method);
    });

    return ConformanceResult(
      ok: failures.isEmpty,
      interfaceClass: interfaceClassName,
      implementationClass: implementationClassName,
      interfaceMethods: interfaceNames,
      implementationOverrides: overrideNames,
      failures: failures,
    );
  }

  /// Method names this generation run contributed to BOTH sides of the
  /// pair (interface declarations and their impl overrides). Used as the
  /// delta-scope audit set for append flows, where pre-existing members
  /// predate this run and are not its claim.
  static Set<String> contributedMethodNames(GeneratorConfig config) {
    final names = <String>{};
    if (config.isCustomUseCase && config.appendToExisting) {
      names.add(config.getRepoMethodName());
    }
    names.addAll(config.methods);
    if (config.generateInit) {
      names.addAll(const ['isInitialized', 'initialize', 'dispose']);
    }
    if (config.enableSync) {
      names.addAll(const ['syncPending', 'pullRemote']);
    }
    return names;
  }

  /// Parses [className] out of [source] and returns its members keyed by
  /// name (declaration order preserved).
  static Map<String, _MemberSignature> _parseMembers(
    String source,
    String className,
  ) {
    final parseResult = const FileParser().parseSource(
      source,
      path: '$className.dart',
    );
    final unit = parseResult.unit;
    if (unit == null) return const {};

    final classNode = const AstHelper().findClass(unit, className);
    if (classNode == null) return const {};

    final members = <String, _MemberSignature>{};
    for (final method in const AstHelper().findMethods(classNode)) {
      final name = method.name.lexeme;
      if (members.containsKey(name)) continue;
      members[name] = _MemberSignature(hasOverride: _hasOverride(method));
    }
    return members;
  }

  static bool _hasOverride(dynamic method) {
    for (final annotation in method.metadata) {
      if (annotation.name.toSource() == 'override') return true;
    }
    return false;
  }
}

class _MemberSignature {
  final bool hasOverride;

  const _MemberSignature({required this.hasOverride});
}

/// Thrown by the repository plugin when the emitted interface/impl pair
/// fails the generation-time conformance gate (spec 0973).
///
/// The CLI runner's catch-all prints this and exits 1; tests using
/// `runCapturing`/`expectLater` catch it without terminating the isolate.
class RepositoryConformanceException implements Exception {
  final ConformanceResult result;

  const RepositoryConformanceException(this.result);

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln(
        'Repository conformance gate failed: '
        '${result.failures.length} mismatch(es) between '
        '${result.interfaceClass} and ${result.implementationClass}:',
      );
    for (final failure in result.failures) {
      buffer.writeln('  [${failure.side}] ${failure.message}');
      buffer.writeln('    ${failure.fix}');
    }
    return buffer.toString().trimRight();
  }
}
