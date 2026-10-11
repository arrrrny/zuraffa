/// SubjectWriter — emits the compilable subject half of a `gen` pair
/// (spec 044-test-tdd-generation, FR-001, FR-003, FR-004, FR-011).
///
/// The emitted subject:
///   - compiles cleanly (FR-011: `dart analyze` reports zero errors);
///   - does NOT satisfy the behavior's expected observable behavior, so the
///     paired test fails for the right reason on first execution (honest
///     red — FR-010);
///   - For `unit` classification: a function-level subject that throws
///     `UnimplementedError()`.
///   - For `acceptance` classification: a behavior-level "scenario runner"
///     that throws `UnimplementedError()`. The acceptance subject does NOT
///     reference any entity/use case/repository — it stands alone (FR-004).
///   - For `widget` classification (bug #830): a view-builder / page
///     contract — a no-argument function returning the feature `Widget` —
///     that the paired widget test pumps inside an app shell. The
///     composition with the entity pipeline (`zfa make --with=vpc` view
///     generation + wire) is the entity-orchestration surface (issue
///     #829); the stub itself stands alone and compiles in any Flutter
///     project. Since issue #959 the widget stub is INERT — it returns
///     `SizedBox.shrink()` (a valid widget that displays nothing) so the
///     authored finder assertions are the red surface — while the other
///     kinds throw `UnimplementedError()`.
///   - For `ffi` classification (bug #835): a NATIVE-BINDING CONTRACT
///     harness — the declared contract (library name + required symbols)
///     plus the three seams the generated contract/golden tests assert
///     through (`symbolResolved`, `roundTrip`, `convertGolden`). Every
///     seam throws `UnimplementedError` until the implementer wires it to
///     the SAME binding production uses; the harness deliberately carries
///     no `dart:ffi` import so it compiles everywhere the loop runs.
library;

import 'dart:io';

import '../models/behavior.dart';
import 'unit_contract_shape.dart';

/// The gen-time honest-red claim sentences the stub header and doc
/// comment carry (issue #1517).
///
/// Single source of truth for both ends of the claim's life: the writer
/// templates below render them, and `func_command`'s dummy-fill step
/// consumes them to rewrite the claims once a dummy body makes them
/// stale — so the two sides cannot drift apart (review of #1523).
///
/// The wraps and `// `/`/// ` comment prefixes are baked in exactly as
/// the templates emit them; the reconciler normalizes them back to
/// spaces before building its wrap-tolerant pattern.
class StubClaims {
  const StubClaims._();

  /// The legacy/undeclared unit stub's honest-red header claim.
  static const unitHeader =
      'This is a MINIMAL COMPILABLE STUB. It compiles cleanly (FR-011) but\n'
      '// does NOT satisfy the behavior described above — the paired test will\n'
      '// fail on first execution with an assertion-level failure (honest red).\n'
      '// Replace this stub body with real implementation to make the test pass.';

  /// The acceptance-scenario stub's honest-red header claim.
  static const acceptanceHeader =
      'This is a MINIMAL COMPILABLE acceptance-scenario stub. It compiles\n'
      '// cleanly (FR-011) but does NOT satisfy the behavior described above —\n'
      '// the paired test will fail on first execution with an assertion-level\n'
      '// failure (honest red). The acceptance subject intentionally does NOT\n'
      '// reference any entity/use case/repository (FR-004): it stands alone.\n'
      '// Replace this stub body with real implementation to make the test pass.';

  /// The contract-derived unit stub's honest-red header claim — emitted
  /// mid-line, after `when implementing. `.
  static const contractHeader =
      'This is a MINIMAL\n'
      '// COMPILABLE STUB: it does NOT satisfy the behavior — the paired test\n'
      '// fails on first execution (honest red). Replace this stub body with\n'
      '// the real implementation of the declared contract to make the test\n'
      '// pass.';

  /// The doc-comment line every stub carries until implemented.
  static const docLine =
      'Throws [UnimplementedError] until the real implementation lands.';
}

/// Writes a minimal compilable Dart subject file for a behavior.
class SubjectWriter {
  const SubjectWriter({this.contractShape});

  /// The contract-derived subject shape (issue #1259): when the
  /// behavior's spec declares the Layer Contract the behavior traces
  /// to, the subject signature is DERIVED from the declaration — params
  /// from the request entity, return from the result entity — never
  /// invented. Null keeps the legacy no-arg int stub for undeclared
  /// behaviors.
  final UnitContractShape? contractShape;

  /// Write the subject file at [subjectPath] for [behavior].
  Future<void> write({
    required Behavior behavior,
    required String subjectPath,
  }) async {
    final file = File(subjectPath);
    await file.parent.create(recursive: true);
    final content = render(behavior);
    await file.writeAsString(content);
  }

  /// Render the subject content the CURRENT binary would write for
  /// [behavior], without touching disk.
  ///
  /// Exposed for `zfa tdd gen`'s staleness check (bug #683): when the
  /// ownership preflight reports `reused/reused`, gen compares the stub
  /// on disk against this render to detect that the generating binary
  /// has changed since the stub was written, and regenerates when they
  /// differ (Option B — lenient content comparison).
  String render(Behavior b) => _renderSubject(b);

  String _renderSubject(Behavior b) {
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final kind = b.kind;
    if (kind == BehaviorKind.ffi) {
      return _renderFfiHarness(b, target);
    }
    if (kind == BehaviorKind.unit) {
      // Issue #1259: a DECLARED Layer Contract derives the signature —
      // the subject shape is the spec's, not an invention.
      if (contractShape != null) {
        return _renderContractUnitSubject(b, target, contractShape!);
      }
      return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// description: ${b.description}
//
// ${StubClaims.unitHeader}
//
// The subject name is derived from the behavior id (`subject_u1`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior ${b.id}.
///
/// ${StubClaims.docLine}
int $target() => throw UnimplementedError('$target not implemented');
''';
    }
    // Widget (bug #830): a view-builder / page contract. Returns the
    // feature Widget the paired testWidgets test pumps. Issue #959: the
    // stub is the INERT RED SURFACE of the widget lane — a valid,
    // renderable widget that displays none of the authored expectations.
    // The generated test's guard passes, the pump runs, and the authored
    // finder assertions fail against this empty view, so red is certified
    // ON the authored assertions (never at the guard — a throwing stub
    // aborts the test and leaves the finders born green).
    if (kind == BehaviorKind.widget) {
      return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: widget
// description: ${b.description}
//
// This is the INERT RED SURFACE of the widget lane (issue #959): a
// valid, renderable view-builder that displays none of the authored
// expectations. The paired widget test's guard passes, the pump runs,
// and the authored finder assertions fail against this empty view —
// red is certified ON the authored assertions, never at the guard.
// Replace this stub body with the real view builder to make the test
// pass (green needs zero edits to the assertions).
//
// The subject name is derived from the behavior id (`subject_a2`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior ${b.id}.
///
/// Inert red surface: replace this body with the real view builder.
Widget $target() => const SizedBox.shrink();
''';
    }
    // Acceptance: emit a "scenario runner" that throws UnimplementedError.
    // The acceptance subject does NOT reference any entity/use case/
    // repository — it stands alone (FR-004).
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// description: ${b.description}
//
// ${StubClaims.acceptanceHeader}
//
// The subject name is derived from the behavior id (`subject_a1`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

/// Scenario runner for behavior ${b.id}.
///
/// ${StubClaims.docLine}
void $target() => throw UnimplementedError('$target not implemented');
''';
  }

  /// The contract-derived unit subject (issue #1259).
  ///
  /// The declared request/result types are preserved in the header and
  /// the doc comment. SPEC 1489: the degradation is CONDITIONAL — a
  /// declared type whose entity EXISTS on disk (phase-0 created it
  /// before gen spawned) renders verbatim, with the entity's import
  /// emitted so the stub compiles against the declared type out of the
  /// box: the author implements the body, never repairs the signature.
  /// Only a declared type whose entity does NOT exist yet degrades to
  /// `Object?` so the stub still compiles cleanly (FR-011) while staying
  /// honestly red. The shape itself — arity, parameter names, scalar
  /// types — comes from the declaration, never invented.
  static String _renderContractUnitSubject(
    Behavior b,
    String target,
    UnitContractShape shape,
  ) {
    // SPEC 1536: the ONE shared renderer — positional params first, the
    // named group as ONE trailing `{...}` block (`{Object? level,
    // Object? onRecord}`); legacy positional rows render byte-for-byte.
    final params = UnitContractShape.renderParameterList(shape.params);
    final paramDocs = shape.params.isEmpty
        ? ''
        : '\n// Declared parameters: ${shape.params.map((p) => '${p.name}: ${p.declaredType}').join(', ')}'
              '${shape.params.any((p) => p.type != p.declaredType) ? ' (non-existent entity types render as Object? until implemented)' : ''}';
    // SPEC 1489: the entity imports ride the stub — the subject
    // compiles against the declared types without any hand repair.
    // Empty when no declared entity exists on disk (the legacy shapes
    // stay byte-identical: the interpolation site keeps the blank line).
    final importBlock = shape.entityImports.isEmpty
        ? '\n'
        : '\n${shape.entityImports.map((uri) => "import '$uri';").join('\n')}\n\n';
    // SPEC 1489: the degradation paragraph is CONDITIONAL — it is only
    // relevant when something actually degraded. A shape whose every
    // declared type renders verbatim (the phase-0 entity already exists)
    // carries no `replace it with the declared type` instruction: the
    // stub is directly implementable as written.
    final anyDegraded =
        shape.returnType != shape.declaredReturn ||
        shape.params.any((p) => p.type != p.declaredType);
    final degradationDocs = anyDegraded
        ? '// The declared request and result types are preserved above. A\n// declared type whose entity does not exist yet renders as `Object?`\n// so the stub compiles cleanly (FR-011) — the degradation is\n// unconditional ONLY for entities that do not exist on disk; replace\n// it with the declared type once the entity lands. '
        : '// The declared request and result types are preserved above: every\n// declared type exists on disk and renders verbatim, import included —\n// implement the body, never the signature. ';
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// description: ${b.description}
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contract:
//
//     ${shape.declaredSignature}
//
$degradationDocs${StubClaims.contractHeader}$paramDocs
//
// The subject name is derived from the behavior id and is deliberately
// snake_cased — the generator KNOWS the name it emits, so the lint its
// shape provably trips is suppressed here rather than renaming the
// contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;
$importBlock/// Subject for behavior ${b.id} — declared contract:
/// `${shape.declaredSignature}`.
///
/// ${StubClaims.docLine}
${shape.returnType} $target($params) => throw UnimplementedError('$target not implemented: ${shape.declaredSignature}');
''';
  }

  /// The FFI binding-contract harness (bug #835).
  ///
  /// The harness is the SEAM the generated tests assert through, not a
  /// mock of the native library: `symbolResolved` / `roundTrip` /
  /// `convertGolden` must be wired to the SAME binding production uses
  /// (typically a small adapter that opens the production
  /// `DynamicLibrary` and calls its exported symbols). Until wired, every
  /// seam throws `UnimplementedError` and the generated contract test is
  /// honestly red — the loop gates on it, it never skips.
  ///
  /// The declared contract constants (`kNativeLibrary`,
  /// `kRequiredSymbols`) are what the contract test iterates; wiring them
  /// is part of implementing the binding, and the harness preserves the
  /// behavior's `target` in the header for traceability.
  static String _renderFfiHarness(Behavior b, String target) {
    return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ffi
// target: $target
// description: ${b.description}
//
// NATIVE-BINDING CONTRACT harness (bug #835). Wire the three seams below
// to the SAME FFI binding production uses, then record the golden data
// under test/tdd fixtures for this behavior. Every seam throws
// UnimplementedError until wired — the paired contract test is honestly
// red until then (honest red, never a skip). The harness carries no
// dart:ffi import so it compiles everywhere the loop runs; the adapter
// you write here is free to use dart:ffi.
library;

/// The production native library this behavior binds (e.g.
/// 'libpdf_to_markdown.so'). Replace the placeholder when the binding is
/// wired — the contract test surfaces it in failure reasons.
const String kNativeLibrary = 'NATIVE_LIBRARY_NOT_CONFIGURED';

/// The symbols the production binding must export for behavior ${b.id}.
/// Replace the placeholder with the real exported symbol names.
const List<String> kRequiredSymbols = <String>[
  'REQUIRED_SYMBOL_NOT_CONFIGURED',
];

/// Whether [symbol] resolves on the wired production binding.
///
/// Throws [UnimplementedError] until the binding is wired.
bool symbolResolved(String symbol) =>
    throw UnimplementedError(
        'wire the production ffi binding for ${b.id}: '
        'symbolResolved(\$symbol)');

/// Marshals [payload] through the wired binding to native memory and
/// back; the contract test asserts the payload round-trips unchanged.
///
/// Throws [UnimplementedError] until the binding is wired.
String roundTrip(String payload) =>
    throw UnimplementedError(
        'wire the production ffi binding for ${b.id}: roundTrip');

/// Runs the production conversion/extraction over the golden fixture
/// input (the pdf/image sample's content or path, per the recorded
/// golden data) and returns the raw output for the fixture assertion.
///
/// Throws [UnimplementedError] until the binding is wired.
String convertGolden(String input) =>
    throw UnimplementedError(
        'wire the production ffi binding for ${b.id}: convertGolden');

''';
  }
}
