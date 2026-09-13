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
    // Issue #1363: the emitted signature's names must be UNIQUE by
    // invariant — a repeated declared name (validate(email, email)) or
    // a bare cell colliding with a positional fallback falls back to
    // the positional form for its position (suffix _p<N> on the rare
    // double collision).
    final params = <ContractParam>[];
    final seen = <String>{};
    for (final entry in _splitTopLevel(paramsText).asMap().entries) {
      final parsed = ContractParam.parse(entry.value, index: entry.key);
      if (parsed == null) continue;
      var name = parsed.name;
      if (seen.contains(name)) {
        name = seen.contains('arg${entry.key}')
            ? 'arg${entry.key}_p${entry.key}'
            : 'arg${entry.key}';
      }
      seen.add(name);
      params.add(ContractParam(type: parsed.type, name: name));
    }
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
  ///
  /// [index] is the cell's position in the declared parameter list — the
  /// positional fallback's number. Issue #1363: every fallback hardcoded
  /// `arg0`, so a multi-param contract of bare-name cells emitted
  /// `arg0, arg0` — a duplicate-definition stub that could not compile
  /// and smeared load-errors across the verify-red batch.
  static ContractParam? parse(String cell, {int index = 0}) {
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
      // A bare identifier cell is a declared NAME (the Layer Contracts
      // grammar: `validate(email, password)`) — the type falls back to
      // dynamic. A bare non-identifier cell is an unnamed TYPE: it keeps
      // a positional name.
      if (RegExp(r'^[A-Za-z_]\w*$').hasMatch(trimmed)) {
        return ContractParam(type: 'dynamic', name: trimmed);
      }
      return ContractParam(type: trimmed, name: 'arg$index');
    }
    final type = trimmed.substring(0, split).trim();
    final name = trimmed.substring(split + 1).trim();
    if (type.isEmpty || !RegExp(r'^[A-Za-z_]\w*$').hasMatch(name)) {
      return ContractParam(type: trimmed, name: 'arg$index');
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
/// Scalar declared types get representative literals; complex types and
/// `dynamic`-typed (and empty-typed) declared params get the scaffold
/// placeholder helper invocation (`_argN()`) that throws
/// `UnimplementedError` with the exact instruction — the scaffold fails
/// through an assertion, never an uncaught error, and the author replaces
/// it with a representative value.
///
/// Issue #1541: a `dynamic` declared param no longer resolves to the bare
/// literal `null`. A bare `null` is not a DECLARED-SHAPE representative —
/// an argument-validating implementation legitimately rejects it (the
/// issue's `AgentLog.logger(subsystem as String)` throws for it), and the
/// rejection used to escape `_captured` as an uncaught runner error. The
/// `dynamic` param now takes the unit lane's placeholder discipline
/// (`provide a representative argument`) so the scaffold blocks honestly
/// until the author supplies a representative value. Nullable complex
/// types KEEP `null`: their declared shape IS nullable, so `null` is a
/// legitimate representative argument.
String _representativeArg(String type, int index) {
  final trimmed = type.trim();
  var base = trimmed;
  if (base.endsWith('?')) base = base.substring(0, base.length - 1).trim();
  switch (base) {
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
  // Issue #1541: `dynamic` (and the never-emitted empty type) carry NO
  // declared shape to represent — the placeholder seam asks the author
  // for a representative argument instead of a bare `null`.
  return '_arg$index()';
}

/// Writes the contract test half of a `gen` pair for contract-kind
/// behaviors (issue #1007).
class ContractTestWriter {
  const ContractTestWriter({this.flutterTest = false});

  /// Whether the host project runs on the Flutter test runner
  /// (`flutter_test`) instead of plain `dart test` (issue #1513, the
  /// contract lane of the #1349/#1351 family): on Flutter projects the
  /// plain `test` package is not resolvable — every generated contract
  /// test stopped at `verify-red` with `Couldn't resolve the package
  /// 'test'`. When true, both templates import
  /// `package:flutter_test/flutter_test.dart` (which re-exports the same
  /// group/test/expect API). Defaults to `false` — the pure-Dart output
  /// is byte-stable.
  final bool flutterTest;

  /// The test-framework import both contract templates emit.
  String get _testImport => flutterTest
      ? "package:flutter_test/flutter_test.dart"
      : "package:test/test.dart";

  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden = false,
  }) async {
    final file = File(testPath);
    await file.parent.create(recursive: true);
    final declaration = ContractDeclaration.parse(behavior.description);
    final subjectImport = _subjectImport(testPath, subjectPath);
    await file.writeAsString(
      declaration == null
          ? _renderUnparseable(behavior, subjectImport)
          : _render(behavior, declaration, subjectImport),
    );
  }

  String _render(Behavior b, ContractDeclaration c, String subjectImport) {
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
// proves the implementation at `$subjectImport`
// satisfies the DECLARED contract above. The body enumerates the
// contract's cases; every case must hold for the contract to be
// satisfied. While the method is deliberately unimplemented the test
// fails through an assertion and `zfa tdd verify-red` reports BLOCKED
// (never RED): a failing contract test blocks the cycle from proceeding
// to GREEN until the implementation satisfies the contract.
library;

import '$_testImport';
import '$subjectImport' as subject;

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
      // method does not throw UnimplementedError. A captured rejection
      // (the implementation threw ArgumentError/TypeError/... for the
      // representative argument) PASSES this case: the seam is
      // implemented and validating (issue #1541) — the outcome split is
      // recorded below, never an uncaught error.
      final Object? outcome = _captured(() => impl($args));
      expect(outcome, isNot(isA<UnimplementedError>()),
          reason: '${c.qualifiedMethod} is not implemented — the declared '
              'contract is unsatisfied, so the cycle is BLOCKED and cannot '
              'proceed to GREEN (issue #1007)');
${returnTypeCase == null ? '' : '''
      // Case 3 of $caseCount — return: the invocation satisfies the
      // declared return type `${c.returnType}`. When the captured
      // outcome is a REJECTION (an ArgumentError, TypeError, ... thrown
      // by an argument-validating implementation) the return-type
      // assertion does not run: there is no return value to type-check,
      // and the contract is SATISFIED-WITH-REJECTION (issue #1541).
      if (outcome is! Error && outcome is! Exception) {
        expect(outcome, isA<$returnTypeCase>(),
            reason: '${c.qualifiedMethod} must return the declared type '
                '`${c.returnType}`');
      }
'''}${placeholderArgs.isEmpty ? '' : '''
      // SCAFFOLD PLACEHOLDERS — the placeholder arguments below (complex-
      // typed or dynamic-typed declared params, issue #1541) throw
      // UnimplementedError with the exact instruction. Replace each
      // placeholder with a representative value for its declared type so
      // this contract test exercises the real invocation:
${placeholderArgs.entries.map((entry) => '      //   _arg${entry.key}() -> a representative `${entry.value}` value').join('\n')}
'''}    });
  });
}

/// Captures ANY error the contract seam invocation can throw (issue
/// #1541) as the assertion's actual value — never an uncaught escape into
/// the runner transcript (an uncaught error graded `runner-error`, never
/// a named verdict). The outcome classes stay split at the assertions:
/// an [UnimplementedError] (the unimplemented seam, or a scaffold
/// placeholder argument) drives the BLOCKED verdict through the Case 2
/// assertion; any OTHER captured error (`ArgumentError` from an
/// argument-validating implementation, a `TypeError` from a cast, ...) is
/// a satisfied-with-rejection — the seam is implemented and rejected the
/// scaffold's representative argument.
Object? _captured(Object? Function() invoke) {
  try {
    return invoke();
  } on Object catch (error) {
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
  String _renderUnparseable(Behavior b, String subjectImport) {
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

import '$_testImport';
import '$subjectImport' as subject;

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

  /// The subject import the contract test emits (issue #1513): a
  /// `package:` URI when the subject sits under the enclosing project's
  /// `lib/` (#1035 parity — the same rule, the same helper, the unit lane
  /// answers), else the legacy relative shape (non-absolute fixture
  /// paths, no pubspec, subject outside `lib/`).
  ///
  /// The package rule only runs for absolute path pairs — the guard the
  /// unit lane keeps (`behavior_test_writer.dart:440`). A relative
  /// `testPath` would otherwise walk up from the process CWD and could
  /// resolve a `package:` URI belonging to whatever package sits there.
  String _subjectImport(String testPath, String subjectPath) {
    if (p.isAbsolute(subjectPath) && p.isAbsolute(testPath)) {
      final packageImport = BehaviorTestWriter.packageSubjectImportFor(
        testPath,
        subjectPath,
      );
      if (packageImport != null) return packageImport;
    }
    return _relativeSubjectPath(testPath, subjectPath);
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
    // Issue #1443: `void` is NOT renderable for the seam — the paired
    // test captures the invocation result (`final Object? outcome =
    // _captured(() => impl(...))`), and a `void`-returning subject makes
    // that capture a compile error. Render `Object?` like the
    // entity-return case: the seam still throws UnimplementedError until
    // implemented, and the honest red compiles.
    final returnRender =
        _isRenderableType(c.returnType) && c.returnType.trim() != 'void'
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
