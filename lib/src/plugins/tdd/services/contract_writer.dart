/// The CONTRACT pair writers (issue #1007) — the gen pair for
/// `contract`-kind behaviors.
///
/// A contract test is different from a unit test: it proves an
/// implementation satisfies a DECLARED contract, not that a piece of
/// code does what its author said. The pair:
///
/// - [ContractSubjectWriter] emits the CONTRACT SUBJECT harness: the
///   declared case table (one [ContractCase]-shaped const per declared
///   method case) plus the per-case satisfaction seams. Every seam
///   throws `UnimplementedError` until the implementer wires it to the
///   real implementation — the scaffold, never the implementation.
/// - [ContractTestWriter] emits the CONTRACT TEST: it enumerates the
///   subject's case table (one `test` per case) and asserts each case is
///   satisfied — the assertion captures the seam's `UnimplementedError`
///   as its actual value, so a deliberately unimplemented method fails
///   through an assertion (the honest signal verify-red's BLOCKED
///   verdict keys on), never an uncaught error.
///
/// Both writers share the `write` signatures of every other pair
/// (spec 044 / issue #841) so the transactional flow, the registry, and
/// the staleness re-render treat them identically.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';

/// Writes the contract TEST half of a `gen` pair (issue #1007): the test
/// that enumerates the contract's declared method cases and asserts the
/// implementation satisfies them.
class ContractTestWriter {
  const ContractTestWriter();

  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden = false,
  }) async {
    final testFile = File(testPath);
    await testFile.parent.create(recursive: true);
    final relativeSubjectPath = _relativeSubjectPath(testPath, subjectPath);
    await testFile.writeAsString(render(behavior, relativeSubjectPath));
  }

  /// Render the contract test content (exposed for the staleness
  /// re-render, bug #683).
  ///
  /// The test is ONE `test` (the single-test runner's exactly-one
  /// contract, FR-005) whose body ENUMERATES the subject's declared
  /// cases: every case is invoked, the unsatisfied ones are collected,
  /// and the assertion fails through `Expected: [] / Actual:
  /// [unsatisfied claims]` — the honest assertion failure the BLOCKED
  /// verdict keys on (never an uncaught error, never a compile error).
  String render(Behavior b, String relativeSubjectPath) {
    final description = _commentSafe(b.description);
    final escapedDescription = _escape(b.description);
    final escapedGroup = _escape('${b.id} (${b.sourceCriterion})');
    return '''
// GENERATED CONTRACT TEST — `zfa tdd gen ${b.id}` (issue #1007).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: contract
// description: $description
//
// This is a CONTRACT TEST, not an implementation test: it enumerates the
// contract's declared method cases (the subject's case table, generated
// from the spec's Layer Contracts declaration) and asserts the
// implementation satisfies each one. A failing case is a BLOCKED verdict
// — distinct from RED — and blocks the cycle from proceeding to GREEN
// while the declared contract is unsatisfied.
library;

import 'package:test/test.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroup', () {
    test('${_escape(b.id)} — $escapedDescription', () {
      // Enumerate the contract's declared cases and collect the
      // unsatisfied ones (an UnimplementedError seam = an unsatisfied
      // case).
      final unsatisfied = <String>[];
      for (final contractCase in subject.contractCases) {
        final Object? result = (() {
          try {
            return contractCase.satisfied();
          } on UnimplementedError catch (e) {
            return e;
          }
        })();
        if (result is UnimplementedError) {
          unsatisfied.add(contractCase.claim);
        }
      }
      expect(
        unsatisfied,
        isEmpty,
        reason:
            'contract case(s) unsatisfied: '
            '\${unsatisfied.isEmpty ? '(none enumerated)' : unsatisfied.join('; ')}'
            ' — the declared contract blocks the cycle from proceeding '
            'to GREEN (issue #1007)',
      );
    });
  });
}
''';
  }
}

/// Writes the contract SUBJECT half of a `gen` pair (issue #1007): the
/// declared case table + the per-case satisfaction seams.
class ContractSubjectWriter {
  const ContractSubjectWriter();

  Future<void> write({
    required Behavior behavior,
    required String subjectPath,
  }) async {
    final file = File(subjectPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(render(behavior));
  }

  /// Render the contract subject content (exposed for the staleness
  /// re-render, bug #683).
  String render(Behavior b) {
    final contract = _contractOf(b);
    final interface = contract.interface;
    final method = contract.method;
    final signature = contract.signature;
    return '''
// GENERATED CONTRACT SUBJECT — `zfa tdd gen ${b.id}` (issue #1007).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: contract
// description: ${_commentSafe(b.description)}
//
// This is the CONTRACT HARNESS, not an implementation: the declared case
// table below enumerates the contract's method cases, and every case's
// satisfaction seam throws [UnimplementedError] until the implementer
// wires it to the real implementation. Replace each seam body so every
// case is satisfied; the paired contract test goes green when (and only
// when) the implementation satisfies the declared contract.
library;

/// One declared case of the contract (issue #1007): what the
/// implementation must satisfy. [satisfied] invokes the case against the
/// implementation — it throws [UnimplementedError] while the case is
/// unsatisfied (the BLOCKED verdict's signal).
class ContractCase {
  const ContractCase({
    required this.id,
    required this.claim,
    required this.satisfied,
  });

  /// The case's 1-based number in the contract's enumeration.
  final int id;

  /// The case's claim: the declared signature (or facet) it asserts.
  final String claim;

  /// Invokes the case against the implementation.
  final Object? Function() satisfied;
}

/// The declared method cases of the contract
/// `$interface.$method` (issue #1007): the implementation must satisfy
/// every case.
const List<ContractCase> contractCases = [
  ContractCase(
    id: 1,
    claim: '$interface exposes $signature',
    satisfied: _case1,
  ),
  ContractCase(
    id: 2,
    claim: '$interface.$method satisfies the declared `$signature`',
    satisfied: _case2,
  ),
];

/// Case 1 — the implementation EXPOSES the declared method on its
/// surface. Wire this to the implementation's method reference
/// (`() => $interface().$method`).
Object? _case1() =>
    throw UnimplementedError('$interface exposes $signature');

/// Case 2 — invoking the declared method SATISFIES the contract. Wire
/// this to a real invocation (`() => $interface().$method(...)`).
Object? _case2() => throw UnimplementedError(
      '$interface.$method satisfies the declared `$signature`',
    );
''';
  }
}

/// The declared contract a behavior row carries (issue #1007): the
/// interface name, the bare method name, and the declared signature.
///
/// Plan-derived rows carry the description
/// `Interface.method must satisfy the declared contract `<signature>``
/// and the traces `Interface.method`; hand-written rows may carry the
/// call shape `Interface.method(params)` in the description or just the
/// `Interface.method` traces. The extraction tries each shape in turn
/// and falls back to the traces, so every committed row shape resolves.
({String interface, String method, String signature}) _contractOf(Behavior b) {
  final traces = b.sourceCriterion.trim();
  // A backticked declared signature in the description (plan-rendered).
  final backticked = RegExp(r'`([^`]+)`').firstMatch(b.description);
  String? signature = backticked?.group(1)?.trim();
  // A call-shaped token (`Interface.method(params)`, optionally with
  // `-> Return`) anywhere in the description or traces.
  signature ??= RegExp(
    r'([A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*\s*\([^)]*\)'
    r'(?:\s*->\s*[^`\s,]+)?)',
  ).firstMatch('${b.description} $traces')?.group(1)?.trim();
  // Bare-method traces: `Interface.method` -> `Interface.method()`.
  final bare = RegExp(
    r'^([A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*)$',
  ).firstMatch(traces);
  if (signature == null && bare != null) {
    signature = '${bare.group(1)!}()';
  }
  signature ??= traces.isEmpty ? '${b.id}()' : '$traces()';

  // The interface.method pair: from the signature, else the traces.
  final pair =
      RegExp(
        r'([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)',
      ).firstMatch(signature) ??
      RegExp(
        r'([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)',
      ).firstMatch(traces);
  final interface = pair?.group(1) ?? 'subject';
  final method = pair?.group(2) ?? signature.split('(').first;
  return (interface: interface, method: method, signature: signature);
}

/// The test→subject relative import path (the same depth computation
/// [BehaviorTestWriter] uses).
String _relativeSubjectPath(String testPath, String subjectPath) {
  if (p.isAbsolute(subjectPath) && p.isAbsolute(testPath)) {
    // Compute the relative path from testPath's parent to subjectPath.
    return p.relative(subjectPath, from: p.dirname(testPath));
  }
  // Otherwise, just return the subject path as-is.
  return subjectPath;
}

String _escape(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

String _commentSafe(String value) => value.replaceAll('\n', ' ');
