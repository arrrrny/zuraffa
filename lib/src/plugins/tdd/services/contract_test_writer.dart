/// Contract test + contract seam writers (issue #1007) — the `zfa tdd gen`
/// pair for a CONTRACT-kind behavior.
///
/// A contract test is different from a unit test: it proves an
/// implementation satisfies a **declared contract** (one entity method,
/// controller method or usecase of the spec's Layer Contracts section),
/// not that a piece of code does what its author said. This is the
/// substrate for `zfa dream` — without contract tests, generated and
/// hand-written code are graded by different rules.
///
/// The pair:
/// - [ContractTestWriter] emits a contract test SCAFFOLD (not an
///   implementation test): ONE test whose body enumerates the contract's
///   CASES — the signature case (the declared method is exposed as
///   declared), the implementation case (invoking it does not throw
///   `UnimplementedError`) and, for scalar returns, the return-type case
///   — asserting the implementation satisfies them.
/// - [ContractSubjectWriter] emits the CONTRACT SEAM: a standalone
///   top-level function with the declared method's name and signature
///   that throws `UnimplementedError` until the contract is implemented
///   (or wired to the production method).
///
/// While the method is deliberately unimplemented the test fails through
/// an assertion (`_captured` turns the `UnimplementedError` into the
/// assertion's actual value, mirroring the ffi lane's pattern), and
/// `zfa tdd verify-red` grades it **BLOCKED** — never RED — with its own
/// receipt (`contract-blocked.<id>.json`). A failing contract test blocks
/// the cycle from proceeding to GREEN.
///
/// The behavior's description is the STRUCTURED contract carrier plan
/// writes (`plan_command._deriveContractBehaviors`):
///
///     <Interface>.<method>(<params>) -> <Return> (<category> contract)
///
/// Both writers parse it through [ContractDeclaration.parse]. Complex
/// declared types (entity types, `Result<...>`) stay compilable: the
/// seam renders them as `Object?` (with the declared type preserved in
/// the doc comment), and the test's invocation case carries a
/// placeholder argument helper that throws `UnimplementedError` with the
/// exact instruction — the scaffold stays honestly failing through
/// assertions until the author provides a representative value.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'behavior_test_writer.dart' show BehaviorTestWriter;

/// One parsed contract declaration.
class ContractDeclaration {
  const ContractDeclaration({
    required this.interface,
    required this.method,
    required this.params,
    required this.returnType,
    required this.category,
  });

  /// The declared interface (entity, controller, usecase or generic
  /// layer interface) — `User` for `User.validateEmail(...) -> bool`.
  final String interface;

  /// The declared method name — `validateEmail`.
  final String method;

  /// The declared parameters, in declaration order.
  final List<ContractParam> params;

  /// The declared return type, verbatim (`bool`,
  /// `Future<Result<bool, String>>`, `void`, ...).
  final String returnType;

  /// The contract category — `entity method`, `controller method`,
  /// `usecase` or `interface method`.
  final String category;

  /// The declared signature as the spec wrote it (`User`-qualified).
  String get qualifiedMethod => '$interface.$method';

  /// Parse the structured description plan writes for contract rows.
  /// Returns null when the description does not carry the shape (the
  /// caller then treats the behavior as unparseable — errors are an API).
  static ContractDeclaration? parse(String description) {
    var text = description.trim();
    // Strip the trailing ` (<category> contract)` marker.
    final categoryMatch = RegExp(
      r'\s*\(([^()]*)\s+contract\)\s*$',
    ).firstMatch(text);
    var category = 'interface method';
    if (categoryMatch != null) {
      category = categoryMatch.group(1)!.trim();
      text = text.substring(0, categoryMatch.start).trim();
    }
    final dot = text.indexOf('.');
    if (dot <= 0) return null;
    final interface = text.substring(0, dot).trim();
    var signature = text.substring(dot + 1).trim();
    // Split the return: the LAST top-level `->` (params never carry one;
    // an exotic function-typed return may).
    var returnType = '';
    final arrow = _lastTopLevelArrow(signature);
    if (arrow != null) {
      returnType = signature.substring(arrow + 2).trim();
      signature = signature.substring(0, arrow).trim();
    }
    final open = signature.indexOf('(');
    if (open <= 0) return null;
    final method = signature.substring(0, open).trim();
    if (!RegExp(r'^[A-Za-z_]\w*$').hasMatch(method)) return null;
    final close = signature.lastIndexOf(')');
    if (close < open) return null;
    final paramsText = signature.substring(open + 1, close).trim();
    final params = _splitTopLevel(paramsText)
        .map((cell) => ContractParam.parse(cell))
        .whereType<ContractParam>()
        .toList();
    return ContractDeclaration(
      interface: interface,
      method: method,
      params: params,
      returnType: returnType.isEmpty ? 'void' : returnType,
      category: category,
    );
  }

  /// The index of the last `->` at bracket depth zero, null when absent.
  /// The arrow is detected at its `>` BEFORE depth tracking — the `->`
  /// token is not a type bracket, so its own `>` must not open a depth
  /// level for the `-` behind it.
  static int? _lastTopLevelArrow(String text) {
    var depth = 0;
    for (var i = text.length - 1; i >= 0; i--) {
      final c = text[i];
      if (c == '>' && i > 0 && text[i - 1] == '-' && depth == 0) {
        return i - 1;
      }
      if (c == ')' || c == '>') depth++;
      if (c == '(' || c == '<') depth--;
    }
    return null;
  }

  /// Split [text] on commas at bracket depth zero (generic `A<B, C>`
  /// stays one cell). Empty text yields no cells.
  static List<String> _splitTopLevel(String text) {
    if (text.isEmpty) return const [];
    final cells = <String>[];
    var depth = 0;
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '<' || c == '(') depth++;
      if (c == '>' || c == ')') depth--;
      if (c == ',' && depth == 0) {
        cells.add(text.substring(start, i));
        start = i + 1;
      }
    }
    cells.add(text.substring(start));
    return cells.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  }
}

/// One declared parameter: an optional name plus a (possibly generic)
/// type, either shape — `String email` or `LoginParams`.
class ContractParam {
  const ContractParam({required this.type, required this.name});

  /// The declared type, verbatim (`String`, `Result<bool, String>`).
  final String type;

  /// The declared name; `arg0`-style when the declaration carried none.
  final String name;

  /// Parse one parameter cell. Null when the cell is not a plausible
  /// parameter (empty or malformed).
  static ContractParam? parse(String cell) {
    final trimmed = cell.trim();
    if (trimmed.isEmpty) return null;
    // The LAST top-level space separates type from name when the cell
    // carries both (`String email`, `Result<bool, String> session`).
    var depth = 0;
    int? split;
    for (var i = trimmed.length - 1; i >= 0; i--) {
      final c = trimmed[i];
      if (c == '>' || c == ')') depth++;
      if (c == '<' || c == '(') depth--;
      if (c == ' ' && depth == 0) {
        split = i;
        break;
      }
    }
    if (split == null) {
      return ContractParam(type: trimmed, name: 'arg0');
    }
    final type = trimmed.substring(0, split).trim();
    final name = trimmed.substring(split + 1).trim();
    if (type.isEmpty || !RegExp(r'^[A-Za-z_]\w*$').hasMatch(name)) {
      return ContractParam(type: trimmed, name: 'arg0');
    }
    return ContractParam(type: type, name: name);
  }
}

/// The scalar (and directly renderable) Dart types the seam and the
/// test's return-type case can carry verbatim without any import.
const Set<String> _scalarTypes = {
  'void',
  'Never',
  'bool',
  'String',
  'int',
  'double',
  'num',
  'dynamic',
  'Object',
};

bool _isRenderableType(String type) {
  final trimmed = type.trim();
  var base = trimmed;
  if (base.endsWith('?')) base = base.substring(0, base.length - 1);
  if (_scalarTypes.contains(base)) return true;
  final generic = RegExp(
    r'^(Future|Stream|List|Set|Iterable)<(.+)>$',
  ).firstMatch(base);
  if (generic != null) {
    return _isRenderableType(generic.group(2)!.trim());
  }
  final map = RegExp(r'^Map<\s*([^,>]+)\s*,\s*(.+)>$').firstMatch(base);
  if (map != null) {
    return _isRenderableType(map.group(1)!.trim()) &&
        _isRenderableType(map.group(2)!.trim());
  }
  return false;
}

/// The types the test's return-type case asserts on (`isA<...>()`) —
/// the non-nullable scalars only (everything else would need imports or
/// unwrapping to assert meaningfully).
String? _returnCaseType(String returnType) {
  final base = returnType.trim();
  if (_scalarTypes.contains(base) && base != 'void' && base != 'dynamic') {
    if (base == 'Never') return null;
    return base;
  }
  return null;
}

/// The representative argument expression for a declared parameter type.
/// Complex types get a placeholder helper invocation (`_argN()`) that
/// throws `UnimplementedError` with the exact instruction — the scaffold
/// fails through an assertion, never an uncaught error, and the author
/// replaces it with a representative value.
String _representativeArg(String type, int index) {
  final trimmed = type.trim();
  var base = trimmed;
  if (base.endsWith('?')) base = base.substring(0, base.length - 1).trim();
  switch (base) {
    case '':
    case 'dynamic':
      return 'null';
    case 'String':
      return "'contract-sample'";
    case 'int':
    case 'num':
      return '0';
    case 'double':
      return '0.0';
    case 'bool':
      return 'false';
    case 'Object':
      return 'Object()';
  }
  // A nullable complex type accepts null as its representative value.
  if (trimmed.endsWith('?')) return 'null';
  return '_arg$index()';
}

/// Writes the contract test half of a `gen` pair for contract-kind
/// behaviors (issue #1007).
class ContractTestWriter {
  const ContractTestWriter();

  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden = false,
  }) async {
    final file = File(testPath);
    await file.parent.create(recursive: true);
    final declaration = ContractDeclaration.parse(behavior.description);
    await file.writeAsString(
      declaration == null
          ? _renderUnparseable(
              behavior,
              _relativeSubjectPath(testPath, subjectPath),
            )
          : _render(
              behavior,
              declaration,
              _relativeSubjectPath(testPath, subjectPath),
            ),
    );
  }

  String _render(
    Behavior b,
    ContractDeclaration c,
    String relativeSubjectPath,
  ) {
    final escapedDescription = BehaviorTestWriter.escapeDartString(
      b.description,
    );
    final escapedGroupDescription = BehaviorTestWriter.escapeDartString(
      '${b.id} (${b.sourceCriterion})',
    );
    final returnTypeCase = _returnCaseType(c.returnType);
    final caseCount = 2 + (returnTypeCase != null ? 1 : 0);
    final placeholderArgs = <int, String>{};
    for (var i = 0; i < c.params.length; i++) {
      final arg = _representativeArg(c.params[i].type, i);
      if (arg.startsWith('_arg')) placeholderArgs[i] = c.params[i].type;
    }
    final args = [
      for (var i = 0; i < c.params.length; i++)
        _representativeArg(c.params[i].type, i),
    ].join(', ');
    final paramSummary = c.params.isEmpty
        ? 'no parameters'
        : c.params.map((param) => '${param.type} ${param.name}').join(', ');

    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (issue #1007, contract lane).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: contract
// description: ${b.description}
//
// CONTRACT TEST (issue #1007): this is NOT an implementation test — it
// proves the implementation at `$relativeSubjectPath`
// satisfies the DECLARED contract above. The body enumerates the
// contract's cases; every case must hold for the contract to be
// satisfied. While the method is deliberately unimplemented the test
// fails through an assertion and `zfa tdd verify-red` reports BLOCKED
// (never RED): a failing contract test blocks the cycle from proceeding
// to GREEN until the implementation satisfies the contract.
library;

import 'package:test/test.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    test('${b.id} \\u2014 $escapedDescription', () {
      // Case 1 of $caseCount — signature: the declared method
      // `${c.qualifiedMethod}($paramSummary) -> ${c.returnType}` is
      // exposed by the implementation subject.
      final impl = subject.${c.method};
      expect(impl, isNotNull,
          reason: '${c.qualifiedMethod} must be exposed with the declared '
              'signature `($paramSummary) -> ${c.returnType}`');

      // Case 2 of $caseCount — implementation: invoking the declared
      // method does not throw UnimplementedError.
      final Object? outcome = _captured(() => impl($args));
      expect(outcome, isNot(isA<UnimplementedError>()),
          reason: '${c.qualifiedMethod} is not implemented — the declared '
              'contract is unsatisfied, so the cycle is BLOCKED and cannot '
              'proceed to GREEN (issue #1007)');
${returnTypeCase == null ? '' : '''
      // Case 3 of $caseCount — return: the invocation satisfies the
      // declared return type `${c.returnType}`.
      expect(outcome, isA<$returnTypeCase>(),
          reason: '${c.qualifiedMethod} must return the declared type '
              '`${c.returnType}`');
'''}${placeholderArgs.isEmpty ? '' : '''
      // SCAFFOLD PLACEHOLDERS — the complex-typed arguments below throw
      // UnimplementedError with the exact instruction. Replace each
      // placeholder with a representative value for its declared type so
      // this contract test exercises the real invocation:
${placeholderArgs.entries.map((entry) => '      //   _arg${entry.key}() -> a representative `${entry.value}` value').join('\n')}
'''}    });
  });
}

/// Captures an [UnimplementedError] thrown by an unimplemented contract
/// seam (or a scaffold placeholder argument) as the assertion's actual
/// value, so the blocked state fails through an assertion (never an
/// uncaught error).
Object? _captured(Object? Function() invoke) {
  try {
    return invoke();
  } on UnimplementedError catch (error) {
    return error;
  }
}

${placeholderArgs.isEmpty ? '' : placeholderArgs.entries.map((entry) => """
/// Scaffold placeholder for parameter ${entry.key} (declared type
/// `${entry.value}`). Replace with a representative value.
Object? _arg${entry.key}() =>
    throw UnimplementedError('provide a representative `${entry.value}` '
        'value for the `${c.qualifiedMethod}` contract test');
""").join('\n')}''';
  }

  /// The refusal-shaped test for a contract row whose description lost
  /// the structured shape: a single failing assertion naming the drift
  /// (format drift is surfaced, not papered over — house pattern).
  String _renderUnparseable(Behavior b, String relativeSubjectPath) {
    final escapedDescription = BehaviorTestWriter.escapeDartString(
      b.description,
    );
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (issue #1007, contract lane).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: contract
// description: ${b.description}
//
// UNPARSEABLE CONTRACT: the behavior description does not carry the
// structured `<Interface>.<method>(<params>) -> <Return>` shape plan
// writes for contract rows. The test fails until the row is re-planned
// (`zfa tdd plan <feature>`) or hand-corrected to the shape.
library;

import 'package:test/test.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('${BehaviorTestWriter.escapeDartString('${b.id} (${b.sourceCriterion})')}', () {
    test('${b.id} \\u2014 $escapedDescription', () {
      // Case 1 of 1 — declaration: the row must carry the structured
      // contract description `zfa tdd plan` writes.
      expect(subject.kContractDeclarationDrift, isNull,
          reason: 'the behavior description must carry the structured '
              'contract shape `<Interface>.<method>(<params>) -> '
              '<Return>` (<category> contract) — re-plan the feature');
    });
  });
}
''';
  }

  String _relativeSubjectPath(String testPath, String subjectPath) {
    if (p.isAbsolute(subjectPath) && p.isAbsolute(testPath)) {
      return p.relative(subjectPath, from: p.dirname(testPath));
    }
    return subjectPath;
  }
}

/// Writes the contract seam (subject) half of a `gen` pair for
/// contract-kind behaviors (issue #1007): a standalone top-level
/// function with the declared method's name and signature that throws
/// [UnimplementedError] until the contract is implemented.
class ContractSubjectWriter {
  const ContractSubjectWriter();

  Future<void> write({
    required Behavior behavior,
    required String subjectPath,
  }) async {
    final file = File(subjectPath);
    await file.parent.create(recursive: true);
    final declaration = ContractDeclaration.parse(behavior.description);
    await file.writeAsString(
      declaration == null
          ? _renderUnparseable(behavior)
          : _render(behavior, declaration),
    );
  }

  String _render(Behavior b, ContractDeclaration c) {
    final returnRender = _isRenderableType(c.returnType)
        ? c.returnType
        : 'Object?';
    final params = c.params.isEmpty
        ? ''
        : c.params
              .asMap()
              .entries
              .map((entry) {
                final type = _isRenderableType(entry.value.type)
                    ? entry.value.type
                    : 'Object?';
                return '$type ${entry.value.name}';
              })
              .join(', ');
    final signature = '${c.method}($params)';
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (issue #1007).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: contract
// target: ${b.target}
// description: ${b.description}
//
// CONTRACT SEAM (issue #1007): this file is where the declared contract
// `${c.qualifiedMethod}(${c.params.map((param) => '${param.type} ${param.name}').join(', ')}) -> ${c.returnType}`
// (${c.category} contract) gets its implementation. Implement the seam
// below — or wire it to the production method. The paired contract test
// enumerates the contract's cases and stays BLOCKED (never RED) until
// every case is satisfied.
library;

/// Contract seam for `${c.qualifiedMethod}($params) -> ${c.returnType}`
/// (${c.category} contract, declared in the spec's Layer Contracts
/// section).
///
/// Throws [UnimplementedError] until the contract is implemented.
$returnRender $signature =>
    throw UnimplementedError(
        '${c.qualifiedMethod}(${c.params.map((param) => param.type).join(', ')}) -> ${c.returnType} '
        'is not implemented');
''';
  }

  /// The refusal-shaped subject for an unparseable contract row: a
  /// typed drift marker the paired test asserts on (compilable on its
  /// own — the test's red is the surfaced drift).
  String _renderUnparseable(Behavior b) {
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (issue #1007).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: contract
// target: ${b.target}
// description: ${b.description}
//
// UNPARSEABLE CONTRACT: the behavior description does not carry the
// structured `<Interface>.<method>(<params>) -> <Return>` shape plan
// writes for contract rows. Re-plan the feature (`zfa tdd plan`) or
// hand-correct the row; the paired test fails until then.
library;

/// Non-null while the row's contract description has drifted from the
/// structured shape `zfa tdd plan` writes (surfaced, not papered over).
const String? kContractDeclarationDrift =
    'contract row "${b.id}" lost its structured declaration';
''';
  }
}
