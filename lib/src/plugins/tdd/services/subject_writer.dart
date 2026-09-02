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
<<<<<<< HEAD
///   - For `widget` classification (bug #830): a view-builder / page
///     contract — a no-argument function returning the feature `Widget` —
///     that the paired widget test pumps inside an app shell. The
///     composition with the entity pipeline (`zfa make --with=vpc` view
///     generation + wire) is the entity-orchestration surface (issue
///     #829); the stub itself stands alone and compiles in any Flutter
///     project.
=======
///   - For `ffi` classification (bug #835): a NATIVE-BINDING CONTRACT
///     harness — the declared contract (library name + required symbols)
///     plus the three seams the generated contract/golden tests assert
///     through (`symbolResolved`, `roundTrip`, `convertGolden`). Every
///     seam throws `UnimplementedError` until the implementer wires it to
///     the SAME binding production uses; the harness deliberately carries
///     no `dart:ffi` import so it compiles everywhere the loop runs.
>>>>>>> be1e86d5 (fix(835): TDD loop TDD-ables native boundaries — ffi-kind behaviors get a binding-contract lane in the loop and a golden fixture lane wired to CI)
library;

import 'dart:io';

import '../models/behavior.dart';

/// Writes a minimal compilable Dart subject file for a behavior.
class SubjectWriter {
  const SubjectWriter();

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
      return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// description: ${b.description}
//
// This is a MINIMAL COMPILABLE STUB. It compiles cleanly (FR-011) but
// does NOT satisfy the behavior described above — the paired test will
// fail on first execution with an assertion-level failure (honest red).
// Replace this stub body with real implementation to make the test pass.
library;

/// Subject for behavior ${b.id}.
///
/// Throws [UnimplementedError] until the real implementation lands.
int $target() => throw UnimplementedError('$target not implemented');
''';
    }
    // Widget (bug #830): a view-builder / page contract. Returns the
    // feature Widget the paired testWidgets test pumps; throws
    // UnimplementedError until the real view lands (honest red).
    if (kind == BehaviorKind.widget) {
      return '''
// GENERATED STUB — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: widget
// description: ${b.description}
//
// This is a MINIMAL COMPILABLE view-builder stub for a UI behavior (bug
// #830): a page contract the entity pipeline composes (issue #829). It
// compiles cleanly (FR-011) but does NOT satisfy the behavior described
// above — the paired widget test fails on first execution through an
// assertion (honest red), because the UnimplementedError is captured
// BEFORE the pump. Replace this stub body with the real view builder.
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior ${b.id}.
///
/// Returns the feature view this behavior's acceptance scenario asserts
/// against. Throws [UnimplementedError] until the real implementation lands.
Widget $target() => throw UnimplementedError('$target not implemented');
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
// This is a MINIMAL COMPILABLE acceptance-scenario stub. It compiles
// cleanly (FR-011) but does NOT satisfy the behavior described above —
// the paired test will fail on first execution with an assertion-level
// failure (honest red). The acceptance subject intentionally does NOT
// reference any entity/use case/repository (FR-004): it stands alone.
// Replace this stub body with real implementation to make the test pass.
library;

/// Scenario runner for behavior ${b.id}.
///
/// Throws [UnimplementedError] until the real implementation lands.
void $target() => throw UnimplementedError('$target not implemented');
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
