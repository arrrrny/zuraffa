import 'package:analyzer/dart/ast/ast.dart';

import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/file_parser.dart';
import '../../../models/generator_config.dart';
import '../generators/entity_usecase_generator.dart';

/// SPEC 1119 — the usecase conformance gate (`zfa usecase verify`,
/// `zfa usecase create --certify`).
///
/// Mirrors the service gate (spec #1127): the expected shape is
/// re-derived by driving the REAL generator
/// ([EntityUseCaseGenerator.buildUsecaseSource] — grammar and gate share
/// one derivation, so the gate can never drift from the grammar), and
/// the generated FILE on disk is audited with the analyzer AST:
///
///   * the prescribed class exists (`missing_class`),
///   * the prescribed `execute` member exists (`missing_method`),
///   * its return/parameter types match the contract
///     (`signature_mismatch`),
///   * and the file parses at all (`parse_error`).
///
/// Extra members the file carries beyond the prescribed surface are
/// tolerated (the append verb grows files by design).
class UsecaseConformanceFinding {
  static const kindParseError = 'parse_error';
  static const kindMissingClass = 'missing_class';
  static const kindMissingMethod = 'missing_method';
  static const kindSignatureMismatch = 'signature_mismatch';

  final String kind;

  /// The member the finding is about ('' for file-level findings).
  final String member;

  /// One human line describing the finding.
  final String message;

  /// The actionable `--> fix:` line (VISION §4: errors are an API).
  final String fix;

  const UsecaseConformanceFinding({
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

/// The verdict of ONE method's conformance audit.
class UsecaseMethodAudit {
  final String method;

  final bool ok;

  /// The audited file (project-relative when the gate resolved it), null
  /// when the contract could not even be derived.
  final String? file;

  /// The prescribed contract (null when the derivation itself failed).
  final UsecaseMethodContract? contract;

  final List<UsecaseConformanceFinding> findings;

  const UsecaseMethodAudit({
    required this.method,
    required this.ok,
    this.file,
    required this.contract,
    required this.findings,
  });

  Map<String, dynamic> toJson() => {
    'name': method,
    'ok': ok,
    if (file != null) 'file': file,
    if (contract != null) ...contract!.toJson(),
    'findings': findings.map((f) => f.toJson()).toList(),
  };
}

class UsecaseConformanceChecker {
  final EntityUseCaseGenerator generator;

  /// The outputDir only shapes the plan's conventional file path — the
  /// audited CLASS shape is path-independent, so a default instance is
  /// safe when the caller does not thread the plugin's generator.
  UsecaseConformanceChecker({EntityUseCaseGenerator? generator})
    : generator = generator ?? EntityUseCaseGenerator(outputDir: 'lib/src');

  /// Audits [source] (the on-disk usecase file) against the contract the
  /// generator prescribes for [config] + [method].
  UsecaseMethodAudit checkMethod({
    required GeneratorConfig config,
    required String method,
    required String source,
    String path = 'usecase_under_audit.dart',
  }) {
    final contract = generator.describeMethod(config, method);
    if (contract == null) {
      return UsecaseMethodAudit(
        method: method,
        ok: false,
        contract: null,
        findings: [
          const UsecaseConformanceFinding(
            kind: UsecaseConformanceFinding.kindParseError,
            member: '',
            message:
                'the method is outside the entity usecase vocabulary — '
                'no contract can be derived',
            fix:
                '--> fix: re-run with a valid --methods set (get, getList, '
                'list, create, update, toggle, delete, watch, watchList)',
          ),
        ],
      );
    }

    final findings = <UsecaseConformanceFinding>[];

    // ── Prescribe: parse the generator-derived expected source. ──
    final parser = const FileParser();
    final expectedParse = parser.parseSource(
      generator.buildUsecaseSource(config, method),
      path: 'expected_${contract.fileName}',
    );
    final expectedClass = expectedParse.unit == null
        ? null
        : AstHelper().findClass(expectedParse.unit!, contract.className);
    final expectedExecute = expectedClass == null
        ? null
        : _executeOf(expectedClass);

    // ── Audit: the actual file must carry the prescribed surface. ──
    final actualParse = parser.parseSource(source, path: path);
    if (actualParse.unit == null || actualParse.hasErrors) {
      findings.add(
        UsecaseConformanceFinding(
          kind: UsecaseConformanceFinding.kindParseError,
          member: contract.className,
          message:
              'the usecase file does not parse cleanly '
              '(${actualParse.errors.length} diagnostics)',
          fix:
              '--> fix: repair the syntax in ${contract.fileName}, or '
              're-run `zfa usecase create ${config.name} --force` to '
              'regenerate it',
        ),
      );
      return UsecaseMethodAudit(
        method: method,
        ok: false,
        contract: contract,
        findings: findings,
      );
    }

    final actualClass = AstHelper().findClass(
      actualParse.unit!,
      contract.className,
    );
    if (actualClass == null) {
      findings.add(
        UsecaseConformanceFinding(
          kind: UsecaseConformanceFinding.kindMissingClass,
          member: contract.className,
          message:
              '${contract.fileName} does not declare the '
              'grammar-prescribed class ${contract.className}',
          fix:
              '--> fix: re-run `zfa usecase create ${config.name} --force` '
              'to regenerate the usecase class the contract prescribes',
        ),
      );
      return UsecaseMethodAudit(
        method: method,
        ok: false,
        contract: contract,
        findings: findings,
      );
    }

    final actualExecute = _executeOf(actualClass);
    if (actualExecute == null) {
      findings.add(
        UsecaseConformanceFinding(
          kind: UsecaseConformanceFinding.kindMissingMethod,
          member: 'execute',
          message:
              '${contract.className} does not declare the prescribed '
              '`execute` member',
          fix:
              '--> fix: restore the prescribed member '
              '`${contract.executeSignature}` on ${contract.className}, or '
              're-run `zfa usecase create ${config.name} --force`',
        ),
      );
      return UsecaseMethodAudit(
        method: method,
        ok: false,
        contract: contract,
        findings: findings,
      );
    }

    // The expected execute signature rides the derived expected class —
    // never hardcoded (grammar and gate share one derivation).
    if (expectedExecute != null) {
      final expectedReturn = _normalize(
        expectedExecute.returnType?.toSource() ?? 'dynamic',
      );
      final actualReturn = _normalize(
        actualExecute.returnType?.toSource() ?? 'dynamic',
      );
      if (expectedReturn != actualReturn) {
        findings.add(
          UsecaseConformanceFinding(
            kind: UsecaseConformanceFinding.kindSignatureMismatch,
            member: 'execute',
            message:
                '${contract.className}.execute returns '
                '`${actualExecute.returnType?.toSource()}` but the '
                'contract prescribes '
                '`${expectedExecute.returnType?.toSource()}`',
            fix:
                '--> fix: restore '
                '`${contract.executeSignature}` on ${contract.className}, '
                'or re-run `zfa usecase create ${config.name} --force`',
          ),
        );
      }

      final expectedParams = _paramShapes(expectedExecute);
      final actualParams = _paramShapes(actualExecute);
      if (expectedParams.length != actualParams.length) {
        findings.add(
          UsecaseConformanceFinding(
            kind: UsecaseConformanceFinding.kindSignatureMismatch,
            member: 'execute',
            message:
                '${contract.className}.execute takes '
                '${actualParams.length} parameter(s) but the contract '
                'prescribes ${expectedParams.length}',
            fix:
                '--> fix: restore '
                '`${contract.executeSignature}` on ${contract.className}, '
                'or re-run `zfa usecase create ${config.name} --force`',
          ),
        );
      } else {
        for (var i = 0; i < expectedParams.length; i++) {
          if (expectedParams[i] == actualParams[i]) continue;
          findings.add(
            UsecaseConformanceFinding(
              kind: UsecaseConformanceFinding.kindSignatureMismatch,
              member: 'execute',
              message:
                  '${contract.className}.execute parameter ${i + 1} is '
                  '`${actualParams[i]}` but the contract prescribes '
                  '`${expectedParams[i]}`',
              fix:
                  '--> fix: restore '
                  '`${contract.executeSignature}` on '
                  '${contract.className}, or re-run '
                  '`zfa usecase create ${config.name} --force`',
            ),
          );
        }
      }
    }

    return UsecaseMethodAudit(
      method: method,
      ok: findings.isEmpty,
      contract: contract,
      findings: findings,
    );
  }

  MethodDeclaration? _executeOf(ClassDeclaration classNode) {
    for (final node in AstHelper().findMethods(classNode, name: 'execute')) {
      return node;
    }
    return null;
  }

  /// The ordered, normalized parameter type shapes of [method] — the
  /// comparison unit for the signature gate.
  List<String> _paramShapes(MethodDeclaration method) {
    final parameters = method.parameters;
    if (parameters == null) return const [];
    return [
      for (final parameter in parameters.parameters)
        _normalize(parameter.type?.toSource() ?? 'dynamic'),
    ];
  }
}

String _normalize(String type) => type.replaceAll(RegExp(r'\s+'), '');
