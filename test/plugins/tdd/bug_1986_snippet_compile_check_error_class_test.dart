// Issue #1986 — SnippetCompileCheck exposes the analyzer diagnostic NAME.
//
// The snippet compile gate (spec 1685) derived its machine-readable code
// from `diagnostic.errorCode.name` — the analyzer's HUMAN-FACING label for
// the diagnostic. The analyzer is free to rename it in any minor release,
// and it did: analyzer 14.5.x reported `undefined_getter`, analyzer 14.6.0
// replaced that diagnostic with `undefined_instance_member_read` (unique
// name `undefined_instance_member_read_not_found`). The rename broke
// `master` (#1980) and was hotfixed by accepting both names (#1981) — a
// fix that the NEXT rename re-breaks.
//
// The durable keys are the analyzer's diagnostic CLASS:
//   * `errorCode.type` — the DiagnosticType (`COMPILE_TIME_ERROR`); it
//     survived the 14.6.0 replacement unchanged and survives every future
//     rename of the diagnostic.
//   * `errorCode.uniqueName` — the analyzer's stable identifier for the
//     diagnostic (distinct from the display name).
//
// These tests pin that the gate exposes BOTH on every issue it reports.
//
// Test map:
//   U-1986-G1 — every analyzer issue exposes `uniqueName` + `errorType`.
//   U-1986-G2 — the exposed keys identify the failure class WITHOUT
//     depending on the analyzer's display name (the rename-prone key).
//   U-1986-G3 — a NON-analyzer issue (the static deny-list scan) carries
//     no analyzer class — the fields are null, not fabricated.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart';

/// The historical misfire from issue #1685, verbatim: `deleteRecursively`
/// is not a member of `dart:io`'s `Directory`.
const _buggySnippet =
    "final _tmp = Directory.systemTemp.createTempSync('x_');\n"
    'addTearDown(_tmp.deleteRecursively);';

void main() {
  group('issue #1986 — snippet compile check exposes the analyzer class', () {
    // ---------------------------------------------------------------
    // U-1986-G1 — the class is exposed on every analyzer issue
    // ---------------------------------------------------------------
    test('U-1986-G1: every analyzer issue exposes its unique name and its '
        'error class', () async {
      final result = await const SnippetCompileCheck().compileCheck(
        _buggySnippet,
      );
      expect(result.passed, isFalse);
      expect(result.errors, isNotEmpty);

      for (final issue in result.errors) {
        expect(
          issue.uniqueName,
          isNotNull,
          reason:
              'every analyzer issue must expose the analyzer unique '
              'name — the rename-proof key (issue #1986)',
        );
        expect(
          issue.errorType,
          isNotNull,
          reason:
              'every analyzer issue must expose the analyzer error '
              'CLASS (DiagnosticType) — the rename-proof key (issue #1986)',
        );
        // The analyzer's identifier conventions: unique names are lower
        // snake_case, DiagnosticType names are UPPER_SNAKE_CASE.
        expect(issue.uniqueName, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(issue.errorType, matches(RegExp(r'^[A-Z][A-Z_]*$')));
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    // ---------------------------------------------------------------
    // U-1986-G2 — the class identifies the failure WITHOUT the
    // rename-prone display name
    // ---------------------------------------------------------------
    test('U-1986-G2: the undefined-member failure is identified by its error '
        'class, not by the analyzer display name', () async {
      final result = await const SnippetCompileCheck().compileCheck(
        _buggySnippet,
      );
      // The analyzer may report MORE than one error-severity diagnostic for
      // this snippet over time (a cascading diagnostic, a lint promoted to
      // an error). Filter by the durable class FIRST, then assert on the
      // match — `single` would throw `StateError: Too many elements`
      // instead of failing with a meaningful assertion.
      final errors = result.errors
          .where((e) => e.errorType == 'COMPILE_TIME_ERROR')
          .toList();
      expect(
        errors,
        isNotEmpty,
        reason: 'the snippet must yield at least one compile-time error',
      );
      final error = errors.first;

      // The error CLASS — unchanged by the 14.5.x → 14.6.0 rename and
      // unchanged by any future rename of the diagnostic.
      expect(
        error.errorType,
        'COMPILE_TIME_ERROR',
        reason: 'the analyzer error CLASS survives every diagnostic rename',
      );

      // The analyzer's unique name stays exposed (it is genuinely useful
      // for diagnostics) but its VALUE is not a contract: analyzer 14.6.0
      // REPLACED the diagnostic rather than relabelling it, and no analyzer
      // API guarantees any naming convention for the family. Assert that it
      // is present and well-formed — never that it matches a name (or a
      // name prefix): that is the coupling #1980/#1981 was about.
      expect(
        error.uniqueName,
        isNotNull,
        reason: 'the analyzer unique name is exposed for diagnostics',
      );
      expect(error.uniqueName, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));

    // ---------------------------------------------------------------
    // U-1986-G3 — no fabricated class on non-analyzer findings
    // ---------------------------------------------------------------
    test('U-1986-G3: a static deny-list finding carries no analyzer class', () {
      final issues = SnippetDenyList.scan(
        'addTearDown(_tmp.deleteRecursively)',
      );
      expect(issues, hasLength(1));
      expect(issues.single.code, 'non_existent_api');
      expect(issues.single.uniqueName, isNull);
      expect(issues.single.errorType, isNull);
    });
  });
}
