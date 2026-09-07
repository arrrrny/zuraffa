import 'package:analyzer/dart/ast/ast.dart';

import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/file_parser.dart';
import '../../../models/generator_config.dart';
import '../builders/service_interface_builder.dart';

/// SPEC 1127 (issue #1127, order 2) — the service grammar-conformance
/// gate.
///
/// The service plugin's schema-grammar sync (issue #978) guarantees the
/// CLI grammar and the schemas advertise the same knobs. This gate closes
/// the loop at the ARTIFACT: it re-derives the member surface the grammar
/// prescribes for a [GeneratorConfig] — by driving the exact
/// [ServiceInterfaceBuilder] generation drives, so the gate can never
/// drift from the grammar — and audits the service file as it exists on
/// disk with the analyzer AST:
///
///   * the prescribed class exists (`missing_class`),
///   * every prescribed member exists (`missing_method`),
///   * every prescribed member's return/parameter types match
///     (`signature_mismatch`),
///   * and the file parses at all (`parse_error`).
///
/// Members the file carries BEYOND the prescribed surface are tolerated
/// (the `zfa service method append` verb grows the interface by design);
/// they are reported informationally in [ServiceConformanceResult.extraMethods],
/// never failed.
class ServiceConformanceFinding {
  static const kindMissingClass = 'missing_class';
  static const kindMissingMethod = 'missing_method';
  static const kindSignatureMismatch = 'signature_mismatch';
  static const kindParseError = 'parse_error';

  final String kind;

  /// The member the finding is about ('' for file-level findings).
  final String member;

  /// One human line describing the finding.
  final String message;

  /// The actionable `--> fix:` line.
  final String fix;

  const ServiceConformanceFinding({
    required this.kind,
    required this.member,
    required this.message,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'member': member,
    'message': message,
    'fix': fix,
  };
}

/// The verdict of one grammar-conformance audit.
class ServiceConformanceResult {
  final bool ok;

  /// The service interface class the grammar prescribes.
  final String serviceClass;

  /// The member names the grammar prescribes (declaration order).
  final List<String> expectedMethods;

  /// Member names present on the audited class beyond the prescribed
  /// surface (growth via `zfa service method append`) — informational.
  final List<String> extraMethods;

  /// The prescribed member signatures (report order).
  final List<String> expectedSignatures;

  final List<ServiceConformanceFinding> findings;

  const ServiceConformanceResult({
    required this.ok,
    required this.serviceClass,
    required this.expectedMethods,
    required this.extraMethods,
    required this.expectedSignatures,
    required this.findings,
  });

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'serviceClass': serviceClass,
    'expectedMethods': expectedMethods,
    'extraMethods': extraMethods,
    'expectedSignatures': expectedSignatures,
    'findings': findings.map((f) => f.toJson()).toList(),
  };
}

/// One prescribed member, read off the grammar-built interface.
class _PrescribedMember {
  final String name;
  final String returnType;
  final bool isGetter;
  final String? paramType;

  const _PrescribedMember({
    required this.name,
    required this.returnType,
    required this.isGetter,
    this.paramType,
  });

  String get signature => isGetter
      ? '$returnType get $name'
      : '$returnType $name(${paramType ?? ''} params)';
}

class ServiceConformanceChecker {
  const ServiceConformanceChecker();

  /// Audits [source] (the on-disk service file) against the surface the
  /// schema grammar prescribes for [config].
  ///
  /// The expected source is BUILT with the same [ServiceInterfaceBuilder]
  /// generation drives — grammar and gate share one derivation, so a
  /// grammar change can never pass the gate with stale expectations.
  ServiceConformanceResult check({
    required GeneratorConfig config,
    required String source,
    String path = 'service_under_audit.dart',
  }) {
    final findings = <ServiceConformanceFinding>[];

    // ── Prescribe: build the grammar surface with the real builder. ──
    final String expectedSource;
    try {
      expectedSource = const ServiceInterfaceBuilder().build(config);
    } catch (e) {
      return ServiceConformanceResult(
        ok: false,
        serviceClass: config.effectiveService ?? '${config.name}Service',
        expectedMethods: const [],
        extraMethods: const [],
        expectedSignatures: const [],
        findings: [
          ServiceConformanceFinding(
            kind: ServiceConformanceFinding.kindParseError,
            member: '',
            message:
                'the schema knobs do not resolve to a service '
                'interface ($e)',
            fix:
                '--> fix: re-run `zfa service create '
                '${config.name} --force` to regenerate from the grammar',
          ),
        ],
      );
    }

    final parser = const FileParser();
    final expectedParse = parser.parseSource(
      expectedSource,
      path: 'expected_service.dart',
    );
    final actualParse = parser.parseSource(source, path: path);

    final className = config.effectiveService ?? '${config.name}Service';
    final prescribed = _prescribedMembersOf(expectedParse.unit, className);

    // ── Audit: the actual file must carry the prescribed surface. ──
    if (actualParse.unit == null || actualParse.hasErrors) {
      findings.add(
        ServiceConformanceFinding(
          kind: ServiceConformanceFinding.kindParseError,
          member: '',
          message:
              'the service file does not parse cleanly '
              '(${actualParse.errors.length} diagnostics)',
          fix:
              '--> fix: repair the syntax in the service file, or re-run '
              '`zfa service create ${config.name} --force` to regenerate it',
        ),
      );
      return _result(
        ok: false,
        className: className,
        prescribed: prescribed,
        extras: const [],
        findings: findings,
      );
    }

    final classNode = AstHelper().findClass(actualParse.unit!, className);
    if (classNode == null) {
      findings.add(
        ServiceConformanceFinding(
          kind: ServiceConformanceFinding.kindMissingClass,
          member: className,
          message:
              'the service file does not declare the '
              'grammar-prescribed abstract class $className',
          fix:
              '--> fix: re-run `zfa service create ${config.name} --force` '
              'to regenerate the interface the schema grammar prescribes',
        ),
      );
      return _result(
        ok: false,
        className: className,
        prescribed: prescribed,
        extras: const [],
        findings: findings,
      );
    }

    final actualMembers = _memberShapesOf(classNode);
    final extras = actualMembers.keys
        .where((n) => !prescribed.containsKey(n))
        .toList(growable: false);

    for (final member in prescribed.values) {
      final shape = actualMembers[member.name];
      if (shape == null) {
        findings.add(
          ServiceConformanceFinding(
            kind: ServiceConformanceFinding.kindMissingMethod,
            member: member.name,
            message:
                'the grammar prescribes `${member.signature}` but '
                '$className does not declare it',
            fix:
                '--> fix: re-run `zfa service create ${config.name} '
                '--force` to regenerate the interface, or add '
                '`$className.${member.signature}`',
          ),
        );
        continue;
      }

      final expectedReturn = _normalize(member.returnType);
      final actualReturn = _normalize(shape.returnType);
      if (expectedReturn != actualReturn) {
        findings.add(
          ServiceConformanceFinding(
            kind: ServiceConformanceFinding.kindSignatureMismatch,
            member: member.name,
            message:
                '$className.${member.name} returns '
                '`${shape.returnType}` but the grammar prescribes '
                '`${member.returnType}`',
            fix:
                '--> fix: restore '
                '`${member.signature}` on $className, or re-run '
                '`zfa service create ${config.name} --force`',
          ),
        );
        continue;
      }

      if (!member.isGetter && member.paramType != null) {
        final actualParam = shape.paramType == null
            ? null
            : _normalize(shape.paramType!);
        final expectedParam = _normalize(member.paramType!);
        if (actualParam != null && actualParam != expectedParam) {
          findings.add(
            ServiceConformanceFinding(
              kind: ServiceConformanceFinding.kindSignatureMismatch,
              member: member.name,
              message:
                  '$className.${member.name} takes '
                  '`${shape.paramType}` but the grammar prescribes '
                  '`${member.paramType}`',
              fix:
                  '--> fix: restore the parameter type '
                  '`(${member.paramType} params)` on '
                  '$className.${member.name}, or re-run `zfa service create '
                  '${config.name} --force`',
            ),
          );
        }
      }
    }

    return _result(
      ok: findings.isEmpty,
      className: className,
      prescribed: prescribed,
      extras: extras,
      findings: findings,
    );
  }

  /// The prescribed surface: members of the grammar-built interface class,
  /// in declaration order.
  Map<String, _PrescribedMember> _prescribedMembersOf(
    Object? unit,
    String className,
  ) {
    final members = <String, _PrescribedMember>{};
    if (unit is! CompilationUnit) return members;
    final classNode = AstHelper().findClass(unit, className);
    if (classNode == null) return members;
    for (final node in AstHelper().findMethods(classNode)) {
      members[node.name.lexeme] = _PrescribedMember(
        name: node.name.lexeme,
        returnType: node.returnType?.toSource() ?? 'dynamic',
        isGetter: node.isGetter,
        paramType:
            node.parameters == null || node.parameters!.parameters.isEmpty
            ? null
            : node.parameters!.parameters.first.type?.toSource(),
      );
    }
    return members;
  }

  /// The actually-declared members of [classNode], keyed by name.
  Map<String, ({String returnType, bool isGetter, String? paramType})>
  _memberShapesOf(ClassDeclaration classNode) {
    final shapes =
        <String, ({String returnType, bool isGetter, String? paramType})>{};
    for (final node in AstHelper().findMethods(classNode)) {
      shapes[node.name.lexeme] = (
        returnType: node.returnType?.toSource() ?? 'dynamic',
        isGetter: node.isGetter,
        paramType:
            node.parameters == null || node.parameters!.parameters.isEmpty
            ? null
            : node.parameters!.parameters.first.type?.toSource(),
      );
    }
    return shapes;
  }

  ServiceConformanceResult _result({
    required bool ok,
    required String className,
    required Map<String, _PrescribedMember> prescribed,
    required List<String> extras,
    required List<ServiceConformanceFinding> findings,
  }) {
    return ServiceConformanceResult(
      ok: ok,
      serviceClass: className,
      expectedMethods: prescribed.keys.toList(growable: false),
      extraMethods: extras,
      expectedSignatures: prescribed.values
          .map((m) => m.signature)
          .toList(growable: false),
      findings: findings,
    );
  }
}

String _normalize(String type) => type.replaceAll(RegExp(r'\s+'), '');
