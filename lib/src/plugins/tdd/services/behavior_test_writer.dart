/// BehaviorTestWriter — emits the failing test half of a `gen` pair
/// (spec 044-test-tdd-generation, FR-001, FR-010, FR-018).
///
/// The generated test:
///   - imports the paired subject file,
///   - asserts the behavior's `description`, NOT a placeholder
///     `expect(true, isFalse)`,
///   - carries the behavior id + source criterion in its group name +
///     doc comment, so the later `verify` report can trace outcomes
///     (FR-018),
///   - fails with an assertion-level failure on first execution
///     (FR-010: honest red — not skipped, not pending, not a compile
///     error, not a load error, not an unconditional placeholder).
///
/// The test asserts the OBSERVABLE behavior described in `behavior.description`.
/// For a description like "returns 42 when invoked with no args", the test
/// calls `subject()` and asserts the result is `42`. The paired subject
/// (emitted by [SubjectWriter]) throws `UnimplementedError`, which the
/// generated assertion captures as a mismatched result so first run is red.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import 'finder_taxonomy.dart';
import 'i18n_key_contract.dart';
import 'unit_contract_shape.dart';
import 'vacuous_guard.dart';
import 'widget_scaffold.dart';

/// Writes a Dart test file that pairs with the subject for a behavior.
class BehaviorTestWriter {
  /// The app shell the generated WIDGET test pumps the feature view in
  /// (issue #912 defect 2): default [WidgetAppShell.zuraffaapp] — zuraffa
  /// apps are zuraffa_ui apps — overridable per project.
  ///
  /// Issue #965: [i18nKeys] carries the feature's declared i18n surfaces;
  /// a scenario literal equal to a declared anchor asserts through the
  /// RESOLVED key (`find.text(t.auth.signIn)`) and the test boots the
  /// slang test shell (accessor import + base-locale pin). [i18nImport]
  /// is the host accessor URI the caller derives from the project's
  /// pubspec (relative fallback) — emitted only when a keyed surface is
  /// emitted. An empty table keeps the pre-#965 template byte-for-byte.
  const BehaviorTestWriter({
    this.widgetShell = WidgetAppShell.zuraffaapp,
    this.i18nKeys = I18nKeyTable.empty,
    this.i18nImport,
    this.i18nExpansion = const [],
    this.contractShape,
    this.flutterTest = false,
    this.projectRoot,
    this.featureDir,
  });

  final WidgetAppShell widgetShell;

  /// The feature's declared i18n surfaces (issue #965).
  final I18nKeyTable i18nKeys;

  /// The host's generated slang accessor URI (nullable — no keyed
  /// surface, no import).
  final String? i18nImport;

  /// The expansion locales (issue #965 optional tier): one extra
  /// `testWidgets` per locale re-pumps the view and re-asserts every
  /// keyed presence surface through its resolved key. Empty = no tier.
  final List<String> i18nExpansion;

  /// The contract-derived subject shape (issue #1259): when the spec
  /// declares the behavior's Layer Contract, the test asserts the
  /// DECLARED outcome surface — a typed `isA<T>()` for scalar declared
  /// returns, or (for entity returns whose type cannot exist yet) the
  /// guard carrying the vacuous-guard marker so `make` refuses green
  /// until a real outcome assertion lands.
  ///
  /// Issue #1512 (review): the UNIT lane only. The acceptance lane's
  /// captured subject is a PARAMETERLESS `void <target>()` scenario
  /// runner ([SubjectWriter] gen stub, preserved by `tdd wire` / `tdd
  /// compose`), and `gen_command.dart` never resolves a shape for an
  /// acceptance row — so an acceptance behavior IGNORES this shape rather
  /// than emitting a pair production never builds. The acceptance row's
  /// declared outcome is asserted through the composition lane the planner
  /// routes to (`generation_planner.dart` branch 3b).
  final UnitContractShape? contractShape;

  /// Whether the host project runs on the Flutter test runner
  /// (`flutter_test`) instead of plain `dart test` (issue #1349/#1351
  /// family): on Flutter projects the plain `test` package is not
  /// resolvable, so the unit/acceptance/ffi/persistence templates import
  /// `package:flutter_test/flutter_test.dart` (which re-exports the same
  /// group/test/expect API). Defaults to `false` — pure-Dart output is
  /// byte-stable.
  final bool flutterTest;

  /// Issue #1518: the seam context the gen-time guard-only warning
  /// resolves the hand-delta seam from — the project root the warning's
  /// paths are relativized against, and the feature dir the lane-plan/
  /// test-list shape check reads from disk. Gen provides both (it has the
  /// resolved feature dir — it may be a `.specify/bugs/<slug>` dir, issue
  /// #1471, so the writer cannot derive it from `behavior.feature`).
  /// Nullable for the direct-library callers (the old `const
  /// BehaviorTestWriter()` keeps compiling): with no context the warning
  /// prescribes the conservative legacy single-file branch — the feature-
  /// derived canonical `specs/<feature>/tdd/test-list.md` path. BOTH
  /// fields must be set for the disk resolution; either one missing falls
  /// back to the conservative branch.
  final String? projectRoot;

  /// Issue #1518: the feature dir of the behavior being written (see
  /// [projectRoot]). Nullable — see [projectRoot].
  final String? featureDir;

  /// The test-framework import the non-widget templates emit.
  String get _testImport => flutterTest
      ? "package:flutter_test/flutter_test.dart"
      : "package:test/test.dart";

  /// Escapes [raw] for safe interpolation into a single-quoted Dart
  /// string literal (issue #912 defect 1): backslash, the single quote
  /// form, `$` (interpolation — a raw `${...}` in a behavior description
  /// must never reach the generated source as code), and control
  /// characters. A double quote is NOT escaped: every interpolation site
  /// is a single-quoted literal, so `\"` would be an UNNECESSARY escape
  /// that trips `unnecessary_string_escapes` in the generated artifact
  /// (issue #1035).
  static String escapeDartString(String raw) {
    final out = StringBuffer();
    for (final code in raw.codeUnits) {
      switch (code) {
        case 0x5C:
          out.write(r'\\');
        case 0x27:
          out.write(r"\'");
        case 0x24:
          out.write(r'\$');
        case 0x0A:
          out.write(r'\n');
        case 0x0D:
          out.write(r'\r');
        case 0x09:
          out.write(r'\t');
        case 0x08:
          out.write(r'\b');
        case 0x0C:
          out.write(r'\f');
        case 0x0B:
          out.write(r'\v');
        default:
          if (code < 0x20 || code == 0x7F) {
            out.write('\\u{${code.toRadixString(16)}}');
          } else {
            out.writeCharCode(code);
          }
      }
    }
    return out.toString();
  }

  /// Makes [raw] safe for a `//` comment line: line breaks would
  /// terminate the comment and spill the remainder into code.
  static String _commentSafe(String raw) =>
      raw.replaceAll('\r', ' ').replaceAll('\n', ' ').replaceAll('\t', ' ');

  /// Write the test file at [testPath] that imports the subject at
  /// [subjectPath] and asserts the behavior's observable behavior.
  ///
  /// [golden] (bug #830, widget kind only) appends a `matchesGoldenFile`
  /// baseline hook whose PNG is committed per platform under
  /// `test/tdd/goldens/` and refreshed with
  /// `flutter test --update-goldens <file>`.
  Future<void> write({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden = false,
  }) async {
    final testFile = File(testPath);
    await testFile.parent.create(recursive: true);
    final relativeSubjectPath = _relativeSubjectPath(testPath, subjectPath);
    final content = behavior.kind == BehaviorKind.ffi
        ? renderContractTest(behavior, testPath, subjectPath)
        : behavior.persistence
        ? _renderPersistenceTest(
            behavior,
            relativeSubjectPath,
            // Issue #912 defect 1: the behavior description reached the
            // persistence template RAW (the parameter was named
            // `escapedDescription` but carried the unescaped text), so a
            // description like "persist the user's theme preference"
            // produced an unterminated string literal.
            escapeDartString('${behavior.id} (${behavior.sourceCriterion})'),
            escapeDartString(behavior.description),
          )
        : behavior.kind == BehaviorKind.widget
        ? _renderWidgetTest(behavior, relativeSubjectPath, golden)
        : _renderTest(behavior, relativeSubjectPath);
    await testFile.writeAsString(content);
    // Issue #1308: the gen-time guard-only warning. When THIS writer emits
    // a guard-only UNIT test for a FALLBACK-ROUTED behavior (no traced
    // contract row — `contractShape == null` — and the prose heuristics
    // did not match), the paired test's only assertion is the bare
    // UnimplementedError guard and `make`'s issue #1259 vacuous-green
    // guard will refuse it: the two-cycle driver dead-ends one step later
    // with no actionable guidance unless gen names the gap NOW. The
    // warning is loud (machine-greppable [vacuousGuardWarningToken] + the
    // shared branched remedy), names the behavior and the gap, and does
    // NOT fail the step: the test is still emitted, exactly as before (the
    // generated shape is unchanged — FR-002/#1308). The traced entity/void
    // path (marker present) stays silent here — its warning is the marker
    // itself, surfaced by the run driver as the designed hand-delta seam.
    // Issue #1518: the remedy line is BRANCHED by feature shape — the
    // seam is resolved from disk exactly like the run-side
    // `_vacuousFallbackRemedy` (#1502), through the same
    // [vacuousGuardFallbackRemedyFor] wording: the pre-#1518 warning
    // hardcoded the pre-#1483 bare-`04-ENGINE.md` advice, so a legacy
    // single-file feature's transcript carried the WRONG remedy first
    // (gen warning → nonexistent lane plan) and the RIGHT remedy second
    // (the stop → the test-list traces cell).
    if (behavior.kind == BehaviorKind.unit &&
        contractShape == null &&
        contentIsVacuousGreen(content) &&
        !contentCarriesVacuousGuardMarker(content)) {
      print(
        'zfa tdd gen: WARNING [$vacuousGuardWarningToken] behavior '
        '"${behavior.id}" — the generated unit test\'s only assertion is '
        'the bare UnimplementedError guard: no `traces:` line to a '
        'declared contract row derives a real outcome assertion, and the '
        'prose heuristics did not match. `make` will refuse this test '
        'vacuous-green (issue #1259) and the run will stop here '
        '(issue #1308).',
      );
      print('   --> fix: ${_guardOnlyRemedy(behavior)}');
    }
  }

  /// Issue #1518: the gen-time guard-only warning's remedy, BRANCHED by
  /// feature shape — resolved from disk exactly like the run-side
  /// `_vacuousFallbackRemedy` (issue #1502), through the ONE shared
  /// [lanePlanSeamPath] resolver so the rule that picks the seam cannot
  /// drift between the two sides again (the engine plan when it exists,
  /// else the skin plan, else the test list — the lane plan pair on disk
  /// is the hand-delta seam; its absence is the legacy single-file shape
  /// and the seam is the test list itself). Paths are printed relative to
  /// [projectRoot] — the full path of the file to edit.
  ///
  /// Without the seam context (either field null — direct library use,
  /// e.g. the writer test suites), the conservative legacy single-file
  /// branch is prescribed: the feature-derived canonical
  /// `specs/<feature>/tdd/test-list.md`. Messaging only — the warning's
  /// fire conditions and the generated test shape are unchanged.
  String _guardOnlyRemedy(Behavior behavior) {
    final root = projectRoot;
    final dir = featureDir;
    if (root != null && dir != null) {
      return vacuousGuardFallbackRemedyFor(
        lanePlanPath: lanePlanSeamPath(projectRoot: root, featureDir: dir),
        testListPath: p.relative(
          p.join(dir, 'tdd', 'test-list.md'),
          from: root,
        ),
      );
    }
    return vacuousGuardFallbackRemedyFor(
      lanePlanPath: null,
      testListPath: p.join('specs', behavior.feature, 'tdd', 'test-list.md'),
    );
  }

  String _renderTest(Behavior b, String relativeSubjectPath) {
    final description = _commentSafe(b.description);
    final escapedDescription = escapeDartString(b.description);
    final escapedGroupDescription = escapeDartString(
      '${b.id} (${b.sourceCriterion})',
    );
    final assertion = _deriveAssertion(b);
    // SPEC 1489: the paired test imports exactly the return entity when
    // its assertion references the declared type (the entity-return
    // scalarOutcome path — `isA<Task>()` cannot compile against an
    // unimported type). Param entities are NOT imported: the `_argN()`
    // placeholders own those (spec 991), so no unused imports. Empty for
    // every legacy shape — the template stays byte-identical.
    final entityImportLines = _testEntityImportLines();
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ${b.kind.name}
// description: $description
//
// This test asserts the observable behavior described above. It is
// "honest red" on first execution: the paired subject at
// `$relativeSubjectPath` is unimplemented, so the test fails through an
// assertion (not an uncaught error, compile/load error, skip, or
// placeholder). Replace the subject's
// stub body with real implementation to make this test pass.
library;

import '$_testImport';
${entityImportLines}import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    test('${b.id} \u2014 $escapedDescription', () {
      $assertion
    });
  });
}
''';
  }

  /// The entity-import lines the paired unit test emits (SPEC 1489): the
  /// declared RETURN entity's import, exactly when the test's assertion
  /// references the declared type — the entity-return `scalarOutcome`
  /// path. The block is terminated by a blank separator line so it stays
  /// visually distinct from the subject import (same idiom as the stub's
  /// `importBlock` in subject_writer.dart). Empty for scalars, for missing
  /// entities (the guard path), and for every legacy shape — the template
  /// stays byte-identical.
  String _testEntityImportLines() {
    final shape = contractShape;
    if (shape == null || !shape.scalarOutcome) return '';
    if (isAssertableScalarType(shape.declaredReturn)) return '';
    if (shape.returnEntityImports.isEmpty) return '';
    return "${shape.returnEntityImports.map((uri) => "import '$uri';").join('\n')}\n\n";
  }

  /// Derive the test's assertion from the behavior description. The
  /// assertion must NOT be a placeholder `expect(true, isFalse)` — it must
  /// assert the observable behavior (FR-010).
  ///
  /// Issue #1259 ordering: a DECLARED Layer Contract derives the
  /// assertion surface FIRST — the spec's declared outcome outranks the
  /// prose heuristics (the #920 "declaration outranks inference"
  /// ordering, now applied to the test half too). The heuristics below
  /// serve undeclared behaviors only.
  ///
  /// Issue #1512 (review): the declared shape is a UNIT-lane surface. An
  /// acceptance behavior never consumes it — its captured subject is a
  /// parameterless `void` scenario runner that returns nothing, so a
  /// declared `isA<T>()` outcome assertion would sit on a value the pair
  /// can never produce. Acceptance rows take the heuristics + the
  /// fallback guard below, and their declared outcome is asserted through
  /// the composition lane (`tdd compose`).
  String _deriveAssertion(Behavior b) {
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final description = b.description;
    final shape = contractShape;
    if (shape != null && b.kind != BehaviorKind.acceptance) {
      return _declaredAssertion(b, target, shape);
    }
    // Look for "returns N" or "= N".
    // On first run, capture the stub's UnimplementedError as the actual
    // result so the value comparison produces an assertion failure.
    final returnsMatch = RegExp(
      r'returns?\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(description);
    if (returnsMatch != null) {
      final expected = returnsMatch.group(1);
      return '${_captureInvocation(b, target, null)}\n'
          '      expect(result, equals($expected));';
    }
    // Look for "throws <ExceptionName>" — only known Dart built-in types
    // to avoid generating unimported exception types from prose.
    const knownExceptions = {
      'FormatException',
      'StateError',
      'ArgumentError',
      'RangeError',
      'TypeError',
      'UnsupportedError',
      'NoSuchMethodError',
      'Exception',
      'Error',
    };
    final throwsMatch = RegExp(
      r'throws?\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(description);
    if (throwsMatch != null) {
      final exc = throwsMatch.group(1)!;
      if (knownExceptions.contains(exc)) {
        if (exc == 'Error') {
          return 'expect(() => subject.$target(), '
              'throwsA(allOf(isA<Error>(), '
              'isNot(isA<UnimplementedError>()))));';
        }
        return 'expect(() => subject.$target(), throwsA(isA<$exc>()));';
      }
      // Unknown exception types and UnimplementedError fall through to the
      // generic assertion to avoid either an unimported type or a green stub.
    }
    // Issue #1512: the UNDECLARED acceptance fallback's guard is the
    // vacuous-green class — the void-safe capture returns null for any
    // non-throwing subject, so an EMPTY body flips it green. Emit the
    // acceptance-lane fallback token naming the lane's actual remedy (the
    // composition lane) so the gap is named on the artifact and the shared
    // `contentIsVacuousGreen` detector refuses it mechanically — never
    // silent. The token is DELIBERATELY not the #1259 `vacuousGuardMarker`:
    // marker presence is the run driver's traced hand-delta seam
    // discriminator (`stopped_at=<id>:hand`, `run_driver_core.dart`), and
    // this fallback is not a traced contract — the marker would reclassify
    // its honest `stopped_at=<id>:make` gap and prescribe an assertion the
    // void scenario runner cannot carry (issue #1512 review). The UNIT
    // lane keeps its #1308 two-class dispatch unchanged (the marker stays
    // ABSENT on the unit fallback path; its gap is the gen-time warning
    // token instead).
    final guard = 'expect(result, isNot(isA<UnimplementedError>()));';
    if (b.kind == BehaviorKind.acceptance) {
      return '${_captureInvocation(b, target, null)}\n'
          '      $acceptanceFallbackGuardComment\n'
          '      $guard';
    }
    return '${_captureInvocation(b, target, null)}\n      $guard';
  }

  /// The contract-derived assertion surface (issue #1259).
  ///
  /// Scalar declared returns assert the declared outcome type
  /// (`expect(result, isA<bool>())`) — an assertion ON the observable
  /// outcome surface the spec declared, never the bare guard. Entity
  /// declared returns cannot reference the declared type before it
  /// exists, so the red surface starts at the guard — but the guard
  /// carries the [vacuousGuardMarker] so `make` refuses green until the
  /// author replaces it with a real outcome assertion.
  String _declaredAssertion(
    Behavior b,
    String target,
    UnitContractShape shape,
  ) {
    final capture = _captureInvocation(b, target, shape);
    if (shape.scalarOutcome) {
      return '$capture\n'
          '      expect(result, isA<${shape.declaredReturn}>());';
    }
    return '$capture\n'
        '      $vacuousGuardComment\n'
        '      expect(result, isNot(isA<UnimplementedError>()));';
  }

  /// The declared parameters' argument expressions at the capture site:
  /// scalar declared types get representative literals; everything else
  /// (entity types that may not exist yet) gets an `_argN()` placeholder
  /// helper whose throw is CAUGHT by the capture (the red stays at the
  /// assertion level) and whose message names the exact remedy.
  ///
  /// Issue #1323 (spec 991 FR-004): `Object` is covered — the
  /// representative expression `Object()` — so the common Object-typed
  /// declared param (e.g. `StreamErrorHandler: reason(Object error) ->
  /// String`) generates a real argument at the capture site and never
  /// dead-ends into the `_argN()` hand-delta seam. Entity-typed and
  /// other non-scalar params keep the seam (FR-003: the escape hatch
  /// stands for truly un-schematicable types).
  static String? _scalarLiteral(String type) {
    switch (type) {
      case 'String':
        return "r'sample'";
      case 'int':
      case 'num':
        return '0';
      case 'bool':
        return 'false';
      case 'double':
        return '0.0';
      case 'Object':
        return 'Object()';
    }
    return null;
  }

  /// The capture + arg-helper block for a declared shape. Helpers are
  /// declared BEFORE the capture (local functions must precede use) and
  /// live inside the test closure.
  ///
  /// Issue #1512 (review): [shape] is the UNIT-lane contract surface. The
  /// acceptance lane IGNORES it — `behavior_test_writer.dart`'s public API
  /// accepts a shape, but `gen_command.dart` resolves one only for
  /// `BehaviorKind.unit`, and the paired acceptance subject is a
  /// parameterless `void <target>()` scenario runner ([SubjectWriter] gen
  /// stub; `tdd wire` / `tdd compose` preserve that signature). Threading
  /// declared args into it, or returning its (void) result, is a
  /// `use_of_void_result` + arity compile error against a pair production
  /// actually builds — so an injected shape is inert here rather than
  /// emitting an artifact only tests can reach.
  String _captureInvocation(
    Behavior behavior,
    String target,
    UnitContractShape? shape,
  ) {
    final acceptance = behavior.kind == BehaviorKind.acceptance;
    final helpers = StringBuffer();
    var args = '';
    if (shape != null && !acceptance) {
      final argExprs = <String>[];
      for (var i = 0; i < shape.params.length; i++) {
        final param = shape.params[i];
        final literal = _scalarLiteral(param.type);
        // SPEC 1536: a named parameter passes a NAMED argument at the
        // capture site (`level: _arg0()`) — the subject's signature
        // renders the `{...}` group, so a positional call would not
        // compile. Positional params keep the legacy argument list.
        final expression = literal ?? '_arg$i()';
        argExprs.add(param.named ? '${param.name}: $expression' : expression);
        if (literal == null) {
          helpers.write(
            "${param.type} _arg$i() => throw UnimplementedError('provide a "
            "representative argument for $target (declared param $i: "
            "${param.declaredType})');\n          ",
          );
        }
      }
      args = argExprs.join(', ');
    }
    // Issue #1035: the UNIT lane's capture initializer is provably
    // non-nullable (the closure returns the subject's value or the
    // caught UnimplementedError — never null), so an explicit `Object?`
    // annotation trips unnecessary_nullable_for_final_variable_declarations
    // in the generated test. Inference types the capture correctly for
    // both the red stub (static return type) and the implemented subject;
    // the acceptance lane's capture IS null (`return null;` — the
    // parameterless void scenario runner has no value to return), so it
    // keeps the explicit nullable annotation its initializer matches.
    //
    // Issue #1512: the acceptance capture stays the VOID-SAFE, ARGUMENT-FREE
    // form. `make`'s vacuous-green refusal is unit-scoped by design
    // (`make_command.dart` step 3c: "acceptance rows keep the legacy skip
    // transition — the composition lane is deferred by design, FR-009"),
    // so the guard-only acceptance test is the lane's correct red surface:
    // the stub throws, the capture returns the error, the guard fails; the
    // composition lane (`tdd compose`) then implements the subject and the
    // guard certifies green.
    final String capture;
    final String invocation;
    if (acceptance) {
      capture = 'final Object? result';
      invocation = 'subject.$target();\n          return null;';
    } else {
      capture = 'final result';
      invocation = 'return subject.$target($args);';
    }
    return '''$helpers$capture = (() {
        try {
          $invocation
        } on UnimplementedError catch (error) {
          return error;
        }
      })();''';
  }

  /// Compute the import URI the generated test uses to reach the paired
  /// subject file.
  ///
  /// Issue #1035: the emitted artifacts must be lint-clean, and a
  /// relative import that reaches into the project's `lib/` from `test/`
  /// provably trips `avoid_relative_lib_imports`. When the subject lives
  /// under the project's `lib/` and the package name is resolvable from
  /// the enclosing `pubspec.yaml`, the import is a `package:` URI
  /// (`package:<name>/<path-under-lib>`). Otherwise (non-absolute fixture
  /// paths, no pubspec), the legacy relative path is kept so the pair
  /// still resolves — and so is portable.
  String _relativeSubjectPath(String testPath, String subjectPath) {
    if (p.isAbsolute(subjectPath) && p.isAbsolute(testPath)) {
      final packageImport = packageSubjectImportFor(testPath, subjectPath);
      if (packageImport != null) return packageImport;
      // Compute the relative path from testPath's parent to subjectPath.
      final rel = p.relative(subjectPath, from: p.dirname(testPath));
      // Ensure it has a `./` or `../` prefix OR is just a relative path.
      return rel;
    }
    // Otherwise, just return the subject path as-is.
    return subjectPath;
  }

  /// The `package:` import URI for [subjectPath] when it sits under the
  /// enclosing project's `lib/` and the package name is resolvable from
  /// the nearest `pubspec.yaml` (walked up from the test file's
  /// directory); null otherwise (caller falls back to the relative shape).
  ///
  /// Issue #1513: promoted from the private instance `_packageSubjectImport`
  /// to a public static so the contract lane answers the same question with
  /// the same rule — one source of truth for the `package:` subject import
  /// across every lane that imports a paired seam.
  static String? packageSubjectImportFor(String testPath, String subjectPath) {
    var dir = p.dirname(testPath);
    String? projectRoot;
    for (var i = 0; i < 24; i++) {
      final candidate = p.join(dir, 'pubspec.yaml');
      if (File(candidate).existsSync()) {
        projectRoot = dir;
        break;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
    if (projectRoot == null) return null;
    final String pubspec;
    try {
      pubspec = File(p.join(projectRoot, 'pubspec.yaml')).readAsStringSync();
    } catch (_) {
      return null;
    }
    final nameMatch = RegExp(
      r'^name:\s*(.+?)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    final packageName = nameMatch?.group(1)?.trim() ?? '';
    if (packageName.isEmpty) return null;
    final libDir = p.join(projectRoot, 'lib');
    if (!p.isWithin(libDir, subjectPath)) return null;
    final underLib = p.relative(subjectPath, from: libDir);
    return 'package:$packageName/$underLib';
  }

  /// Render the WIDGET test (bug #830): a `testWidgets` pair that boots
  /// the feature view through the subject's view-builder contract, pumps
  /// it inside a configurable app shell (issue #912 defect 2 — ZuraffaApp
  /// by default, MaterialApp for plain-Material projects), and asserts
  /// the acceptance scenario through finders DERIVED from the scenario
  /// description (issue #912 defect 3 — a bare `findsOneWidget`
  /// placeholder is greenable by a SizedBox and marks the test
  /// scaffolded).
  ///
  /// Red surfaces (issue #959): the inert stub (`SizedBox.shrink()`,
  /// see SubjectWriter's widget branch) lets the guard pass and the pump
  /// run, so the
  /// AUTHORED FINDER assertions fail at red time — red is certified on
  /// the assertions, never born green. The UnimplementedError capture
  /// BEFORE the pump stays as the SECONDARY guard: a subject that still
  /// throws fails through the guard assertion instead of an exception
  /// escaping pump (which the red classifier routes to runner-error, not
  /// honest red, per issue #830's widget failure taxonomy).
  String _renderWidgetTest(
    Behavior b,
    String relativeSubjectPath,
    bool golden,
  ) {
    final description = _commentSafe(b.description);
    final escapedDescription = escapeDartString(b.description);
    final escapedGroupDescription = escapeDartString(
      '${b.id} (${b.sourceCriterion})',
    );
    final target = b.target.isEmpty ? 'subjectUnderTest' : b.target;
    final snakeId = _toSnakeCase(b.id);
    // Issue #912 defect 2: the shell is configurable; the skin shell
    // needs its own import (material.dart stays for Scaffold + Theme).
    final shellName = widgetShell.widgetName;
    final shellImport = widgetShell.importPath == null
        ? ''
        : "import '${widgetShell.importPath}';\n";
    // Issue #964 (finder-kind taxonomy): the scenario verb decides the
    // assertion class — presence stays find.text, navigation becomes a
    // route-outcome assertion on a recording NavigatorObserver, absence
    // becomes findsNothing, enabled-state asserts onPressed null-ness,
    // and a sequence scenario (while … in flight) is marked scaffolded
    // instead of silently flattened to presence.
    // Issue #965: literals equal to a declared anchor resolve to their
    // slang key BEFORE emission — the test asserts the resolved key
    // through the translation test shell, never the EN string.
    final analysis = FinderTaxonomy.resolveKeys(
      FinderTaxonomy.analyze(b.description),
      i18nKeys,
    );
    final keyedSurfaces = analysis.assertions
        .where((a) => a.kind == LiteralKind.key)
        .toList(growable: false);
    final keyed = keyedSurfaces.isNotEmpty && i18nImport != null;
    // Issue #965: keyed surfaces need the host's generated slang accessor
    // (its global `t` + LocaleSettings). The import lands with the other
    // package imports — only when a keyed surface is emitted.
    final i18nImportLine = keyed ? "import '$i18nImport';\n" : '';
    final finders = FinderTaxonomy.emitTestAssertions(
      analysis,
      escape: escapeDartString,
    );
    final assertionsHeader = FinderTaxonomy.headerLine(analysis);
    final routeObserver = analysis.needsRouteObserver;
    // Issue #912 defect 3 (as refined by issue #964): a test with NO
    // derivable finder is a scaffolded placeholder; a SEQUENCE scenario
    // is scaffolded too (a single pump cannot honestly assert the
    // act → intermediate → final machine), even when it carries
    // derivable sub-assertions.
    final String scenarioBlock;
    if (analysis.sequence) {
      final sequenceComment =
          '// $scaffoldedMarker — SEQUENCE scenario '
          '(issue #964): the scenario describes an in-flight state\n'
          '      // machine (act → intermediate → final). A single-pump '
          'template cannot assert\n'
          '      // the sequence honestly, so this test is SCAFFOLDED, not '
          'certified: implement\n'
          '      // the sequence here (act → pump the intermediate state → '
          'assert → settle →\n'
          '      // assert the final state) and remove this marker before '
          'certifying green.';
      scenarioBlock = finders.isEmpty
          ? sequenceComment
          : '$sequenceComment\n      ${finders.join('\n      ')}';
    } else if (finders.isEmpty) {
      scenarioBlock =
          '$widgetScaffoldComment\n      expect(find.byWidget(view), findsOneWidget);';
    } else if (routeObserver) {
      // Route-outcome scenarios carry NO trailing mounted-view smoke
      // assertion: once the scenario's route is pushed, the home route
      // goes offstage and `find.byWidget(view)` would honestly fail —
      // the pushedNames assertion IS the scenario.
      scenarioBlock = finders.join('\n      ');
    } else {
      scenarioBlock =
          "${finders.join('\n      ')}\n      expect(find.byWidget(view), findsOneWidget);";
    }
    final observerDecl = routeObserver
        ? '      // Route-outcome recording (issue #964): the scenario asserts\n'
              '      // navigation, so pushed ROUTES are observed — never the\n'
              '      // route name rendered as on-screen text.\n'
              '      final observer = _RouteRecorder();\n'
        : '';
    // Bug #1261 scaffold honesty: the header mentions golden baselines
    // ONLY when a golden hook was actually emitted — never when gen ran
    // without a golden gate, and not for a route-outcome scenario (whose
    // hook is withheld per issue #964). The scaffold never promises a
    // harness that does not exist.
    final goldenHookEmitted = golden && !routeObserver;
    final pumpCall = routeObserver
        ? 'await tester.pumpWidget($shellName(\n'
              '        navigatorObservers: <NavigatorObserver>[observer],\n'
              '        home: Scaffold(body: view),\n'
              '      ));'
        : 'await tester.pumpWidget($shellName(home: Scaffold(body: view)));';
    // Issue #965: the translation test shell boots BEFORE the pump — the
    // base locale is pinned so the resolved keys render the anchor copy,
    // a copy edit to the EN string can never break green, and a missing
    // key fails RED honestly.
    final localePin = keyed
        ? "// Slang test shell (issue #965): the base locale is pinned so\n"
              "      // the resolved keys render the anchor copy — a copy edit to\n"
              "      // the EN string can never break green; a missing key fails\n"
              "      // RED honestly (the fallback is the base copy, not a lie).\n"
              "      LocaleSettings.setLocaleRaw('${I18nScaffold.baseLocale}');\n"
        : '';
    // Issue #964 (code review on #981): a route-outcome scenario's
    // golden hook can NEVER pass — after the route pushes, the home
    // route goes offstage and find.byWidget(view) resolves to nothing
    // (the same mechanism that killed the smoke assertion). Skip the
    // hook for route scenarios; goldens stay available for the other
    // assertion classes.
    final goldenBlock = golden && !routeObserver
        ? '''
      // Golden baseline (bug #830): commit one PNG per platform under
      // test/tdd/goldens/ (VISION §6 institutional memory). Refresh with:
      //   flutter test --update-goldens test/tdd/${snakeId}_test.dart
      await expectLater(
        find.byWidget(view),
        matchesGoldenFile('goldens/$snakeId.png'),
      );
'''
        : golden && routeObserver
        ? '''
      // No golden hook (issue #964): a route-outcome scenario's view is
      // offstage once the asserted route is pushed, so a
      // matchesGoldenFile on the home view can never settle. Remove
      // --golden or drop the navigation assertion to use goldens here.
'''
        : '';
    // Issue #965 (optional tier): one expansion testWidgets per locale —
    // the view is re-pumped under the expansion locale (de strings run
    // ~30% longer, catching overflow assumptions before goldens do) and
    // every keyed PRESENCE surface is re-asserted through its resolved
    // key. Absent without the tier or without keyed surfaces.
    final expansionTests = keyed && i18nExpansion.isNotEmpty
        ? keyedSurfaces
              .where((a) => a.assertionClass == ScenarioAssertionClass.presence)
              .map(
                (surface) => _renderExpansionTest(
                  behavior: b,
                  shellName: shellName,
                  target: target,
                  surfaceAccessor: surface.literal,
                  locales: i18nExpansion,
                ),
              )
              .join()
        : '';
    final recorderClass = routeObserver
        ? '''

/// Records pushed route names so route-outcome assertions (issue #964)
/// observe real navigation — the scenario's green measures the ROUTE
/// outcome, not the route name rendered as display text.
class _RouteRecorder extends NavigatorObserver {
  final List<String?> pushedNames = <String?>[];

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    pushedNames.add(route.settings.name);
  }
}
'''
        : '';
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: widget
${keyed ? "// i18n: slang test shell, base locale '${I18nScaffold.baseLocale}' pinned; keyed surfaces resolve (issue #965)\n" : ''}${assertionsHeader.isEmpty ? '' : '$assertionsHeader\n'}// description: $description
//
// This is a WIDGET test (bug #830): it boots the feature view through
// the subject's view-builder contract, pumps it inside a $shellName
// shell, and asserts the acceptance scenario through verb-matched
// assertions (issue #964 finder-kind taxonomy: shows/renders → presence,
// navigates → route outcome via the recorded pushed routes, hides/not
// shown → absence, disables/enables → enabled state; a while/in-flight
// sequence scenario is marked scaffolded). RED SURFACE (issue #959): the
// stub is inert (SizedBox.shrink), so the guard passes, the pump runs,
// and these verb-matched authored finders fail against the empty view —
// red is certified on the assertions, never at the guard. The
// UnimplementedError capture below is the SECONDARY guard: if a subject
// still throws, the error lands in the guard assertion instead of
// escaping the pump (classified runner/compile, not red — issue #830
// widget failure taxonomy). Widget tests run on the flutter profile's
// slower tier${goldenHookEmitted ? '; golden baselines are committed per platform under\n// test/tdd/goldens/' : ''}.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
$shellImport${i18nImportLine}import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    testWidgets('${b.id} \u2014 $escapedDescription', (tester) async {
      // Honest-red capture + secondary guard (issue #959): call the
      // view-builder OUTSIDE pumpWidget so a subject that still throws
      // UnimplementedError lands in the expect below (an assertion
      // failure) instead of escaping the pump as a runner error (issue
      // #830 widget failure taxonomy). With the inert stub this passes
      // and the authored finders below are the primary red surface.
$observerDecl      final Object? built = (() {
        try {
          return subject.$target();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(built, isNot(isA<UnimplementedError>()));
      final view = built! as Widget;
      // Boot the view inside an app shell so Theme.of / ZfaTheme.of /
      // Navigator / MediaQuery lookups resolve (issue #830 remediation 2;
      // shell configurable per issue #912 defect 2).
$localePin      $pumpCall
      await tester.pumpAndSettle();
      // PRIMARY red surface (issue #959 + issue #964 taxonomy):
      // verb-matched authored finders derived from the scenario
      // description (issue #912 defect 3) execute after the pump and
      // fail against the inert stub's empty view — red is certified on
      // these assertions, never a placeholder a bare SizedBox() would
      // satisfy, never a route outcome flattened into presence-of-text.
      $scenarioBlock
$goldenBlock    });$expansionTests
  });
}$recorderClass''';
  }

  /// One expansion-locale `testWidgets` (issue #965 optional tier): the
  /// same view-builder pumped under [locale], every keyed presence
  /// surface re-asserted through its resolved accessor. A missing
  /// expansion key fails RED honestly (slang falls back to the base copy
  /// only when configured — the test never accepts a silent string).
  static String _renderExpansionTest({
    required Behavior behavior,
    required String shellName,
    required String target,
    required String surfaceAccessor,
    required List<String> locales,
  }) {
    final buffer = StringBuffer();
    for (final locale in locales) {
      final trimmed = locale.trim();
      if (trimmed.isEmpty) continue;
      buffer
        ..writeln()
        ..writeln(
          "    testWidgets('${behavior.id} \u2014 expansion locale $trimmed "
          "renders every keyed surface (issue #965)', (tester) async {",
        )
        ..writeln(
          '      // Expansion tier (issue #965, optional): pump the expansion '
          'locale —',
        )
        ..writeln(
          '      // $trimmed strings run ~30% longer, catching overflow '
          'assumptions before',
        )
        ..writeln('      // goldens do. Assertions stay on the RESOLVED keys.')
        ..writeln("      LocaleSettings.setLocaleRaw('$trimmed');")
        ..writeln('      final Object? built = (() {')
        ..writeln('        try {')
        ..writeln('          return subject.$target();')
        ..writeln('        } on UnimplementedError catch (error) {')
        ..writeln('          return error;')
        ..writeln('        }')
        ..writeln('      })();')
        ..writeln('      expect(built, isNot(isA<UnimplementedError>()));')
        ..writeln('      final view = built! as Widget;')
        ..writeln(
          '      await tester.pumpWidget($shellName(home: Scaffold(body: view)));',
        )
        ..writeln('      await tester.pumpAndSettle();')
        ..writeln('      expect(find.text($surfaceAccessor), findsOneWidget,')
        ..writeln(
          "          reason: 'the keyed surface $surfaceAccessor must render "
          "under $trimmed');",
        )
        ..writeln('    });');
    }
    return buffer.toString();
  }

  /// The same snake-case convention `zfa tdd gen` uses for artifact
  /// paths (mirrored locally so the writer stays dependency-free).

  String renderContractTest(Behavior b, String testPath, String subjectPath) {
    final relativeSubjectPath = _relativeSubjectPath(testPath, subjectPath);
    final escapedDescription = escapeDartString(b.description);
    final escapedGroupDescription = escapeDartString(
      '${b.id} (${b.sourceCriterion})',
    );
    return '''
// GENERATED TEST — `zfa tdd gen ${b.id}` (spec 044-test-tdd-generation).
//
// behavior_id: ${b.id}
// source_criterion: ${b.sourceCriterion}
// kind: ffi
// description: ${b.description}
//
// BINDING CONTRACT lane (bug #835). This test asserts the native-binding
// CONTRACT — required symbols resolve, marshalling round-trips — through
// the harness at
// `$relativeSubjectPath`,
// wired to the SAME binding production uses. It runs in the default test
// tier on the host runner. With the binding unwired it is honestly red
// (assertion-level, never skipped). The golden-fixture assertion lives in
// the marked integration lane next to this file (*_golden_test.dart),
// gated by `dart test --preset=integration` in CI.
library;

import '$_testImport';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    test('${b.id} \u2014 $escapedDescription', () {
      // (1) The declared contract: every required symbol resolves on the
      // wired production binding.
      expect(subject.kRequiredSymbols, isNotEmpty,
          reason: 'declare the symbols the production binding must export '
              'in kRequiredSymbols');
      for (final symbol in subject.kRequiredSymbols) {
        final Object? resolved =
            _captured(() => subject.symbolResolved(symbol));
        expect(resolved, isTrue,
            reason: 'symbol "\$symbol" must resolve on '
                '\${subject.kNativeLibrary} (wire the production binding '
                'in the subject harness)');
      }
      // (2) Marshalling: a payload round-trips through the binding
      // to native memory and back unchanged.
      const payload = '${b.id.toLowerCase()}-ffi-round-trip-payload';
      final Object? roundTripped = _captured(() => subject.roundTrip(payload));
      expect(roundTripped, equals(payload),
          reason: 'the binding must marshal the payload to native memory '
              'and back unchanged (wire roundTrip in the subject harness)');
    });
  });
}

/// Captures an [UnimplementedError] thrown by an unwired harness seam as
/// the assertion's actual value, so the unwired state fails through an
/// assertion (honest red) instead of an uncaught error.
Object? _captured(Object? Function() invoke) {
  try {
    return invoke();
  } on UnimplementedError catch (error) {
    return error;
  }
}
''';
  }

  /// The persistence-kind test shape (bug #833).
  String _renderPersistenceTest(
    Behavior b,
    String relativeSubjectPath,
    String escapedGroupDescription,
    String escapedDescription,
  ) {
    final assertion = _deriveAssertion(b);
    final boxName = 'tdd_${_toSnakeCase(b.id)}';
    return '''
// GENERATED TEST for ${b.id} (bug #833 persistence test harness).
//
// Persistence-kind behavior -- the persistence harness is wired in:
//   1. a fresh temp-directory Hive box set is bootstrapped PER TEST and
//      torn down PER TEST (never shared across tests);
//   2. TTL assertions use the injected test clock (advanceTime) -- no
//      real sleeps in the suite;
//   3. corruption drills: harness.seedCorruptedBox('${escapeDartString(boxName)}') +
//      harness.openWithRecovery('${escapeDartString(boxName)}') drive the clear + re-fetch
//      recovery path against a pre-corrupted fixture;
//   4. registrar gate: pass registerAdapters + expectedTypeIds to
//      the harness below so init-time registration failures surface as
//      RegistrarGateError -- a deterministic red at init, not a runtime
//      read crash.
library;

import '$_testImport';
import 'package:zuraffa/zuraffa.dart';
import '$relativeSubjectPath' as subject;

void main() {
  group('$escapedGroupDescription', () {
    final harness = PersistenceTestHarness(boxNames: ['${escapeDartString(boxName)}']);
    final clock = TestClock();

    setUp(() async {
      await harness.bootstrap();
    });

    tearDown(() async {
      await harness.teardown();
    });

    test('${b.id} - $escapedDescription', () {
      clock.advanceTime(const Duration(minutes: 1));
      $assertion
    });
  });
}
''';
  }

  static String _toSnakeCase(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }
}
