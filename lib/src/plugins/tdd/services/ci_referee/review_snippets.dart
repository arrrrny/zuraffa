/// Canonical review-snippet templates (spec 1685): the first-party source
/// of truth for the code suggestions `zuraffa-review[bot]` proposes in PR
/// review comments.
///
/// Issue #1685: the bot's temp-dir-cleanup suggestion proposed
/// `addTearDown(_tmp.deleteRecursively)` on arrrrny/zuraffa_browser#165 —
/// `deleteRecursively` is NOT a member of `dart:io`'s `Directory` (which
/// only has `delete({recursive})` / `deleteSync({recursive})`) and no
/// extension in the snippet's reachable surface provides it. The posted
/// snippet could not compile (`undefined_getter`).
///
/// This catalog is the compilable source of truth: every template emits
/// plain, verifiable dart:io calls — the same cleanup semantics with the
/// API surface the platform actually ships — and the ONLY sanctioned way
/// to obtain a snippet for a posted comment is
/// [ReviewSnippets.postableSnippet], which runs the full validation gate
/// ([SnippetCompileCheck]: deny-list scan + REAL analyzer compile check)
/// before returning. An un-compilable template cannot produce a postable
/// snippet.
///
/// The templates deliberately mirror the codebase's own proven idiom —
/// `addTearDown(() => dir.deleteSync(recursive: true));` as used in
/// `lib/tdd/073-slice-isolation/u1_subject.dart`,
/// `lib/tdd/078-skin-contract-schema/a3_subject.dart` and
/// `test/zap/zap_conformance_test.dart` — so a suggestion, once applied,
/// matches what the repository itself does.
library;

import 'package:zuraffa/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart';

/// One review-suggestion snippet template.
final class ReviewSnippetTemplate {
  const ReviewSnippetTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
  });

  /// Stable identifier (the id a posting path asks the catalog for).
  final String id;

  /// Human-readable name for review-bot logs.
  final String title;

  /// What the snippet does and WHY its API references are compilable
  /// (the audit trail for the template — see the audit notes below).
  final String description;

  /// The template body. `{{dir}}` is the directory-variable placeholder
  /// substituted by [ReviewSnippets.render].
  final String code;

  @override
  String toString() => 'ReviewSnippetTemplate($id)';
}

/// The template catalog. Add new templates here; every entry is gated by
/// [ReviewSnippets.all]'s deny-list invariant (pinned by the SPEC 1685
/// regression suite) and validated through [ReviewSnippets.postableSnippet]
/// before a comment is rendered.
abstract final class ReviewSnippets {
  /// Id of the temp-dir-cleanup template (the #1685 template).
  static const String tempDirCleanupId = 'tempDirCleanup';

  /// The FIXED temp-dir-cleanup template (issue #1685).
  ///
  /// Cleanup semantics identical to the historical (non-compilable)
  /// `addTearDown(_tmp.deleteRecursively)` suggestion: create a unique
  /// directory under the system temp, register a tear-down that removes
  /// it with everything inside — expressed with the APIs dart:io actually
  /// ships: `Directory.systemTemp.createTempSync` and
  /// `Directory.deleteSync(recursive: true)`.
  static const ReviewSnippetTemplate tempDirCleanup = ReviewSnippetTemplate(
    id: tempDirCleanupId,
    title: 'Temp directory cleanup in a test',
    description:
        'Creates a unique temp directory and registers an addTearDown that '
        'deletes it recursively. Uses ONLY compilable dart:io calls '
        '(issue #1685): deleteSync({recursive: true}) — '
        'Directory.deleteRecursively does not exist. The closure form is '
        'required: deleteSync takes a named argument, so a bare tear-off '
        'cannot express the recursive flag.',
    code:
        "final {{dir}} = Directory.systemTemp.createTempSync('review_tmp_');\n"
        'addTearDown(() => {{dir}}.deleteSync(recursive: true));',
  );

  /// The audited catalog (spec 1685 audit: this is the complete set of
  /// first-party review-suggestion templates; every entry's API references
  /// are verified against the snippet's reachable surface — see each
  /// template's description).
  static const List<ReviewSnippetTemplate> all = [tempDirCleanup];

  /// Looks up a template by id. Throws [ArgumentError] for unknown ids —
  /// a posting path must never fall back to ad-hoc template text.
  static ReviewSnippetTemplate templateOf(String id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    throw ArgumentError.value(
      id,
      'id',
      'unknown review-snippet template — known ids: '
          '${all.map((t) => t.id).join(", ")}',
    );
  }

  /// Renders [id] with [directoryVariable] substituted for `{{dir}}`.
  ///
  /// NOT validated — use [postableSnippet] on any path that reaches a
  /// posted comment.
  static String render(String id, {String directoryVariable = 'tmp'}) {
    final template = templateOf(id);
    return template.code.replaceAll('{{dir}}', directoryVariable);
  }

  /// The ONLY sanctioned entry point for posting paths: renders [id] and
  /// runs the full validation gate (deny-list scan + REAL analyzer compile
  /// check) before returning. Throws [SnippetValidationException] if the
  /// rendered snippet does not compile — an un-compilable suggestion is
  /// never posted.
  static Future<String> postableSnippet(
    String id, {
    String directoryVariable = 'tmp',
    SnippetCompileCheck check = const SnippetCompileCheck(),
  }) async {
    final code = render(id, directoryVariable: directoryVariable);
    final result = await check.validate(code);
    if (!result.passed) throw SnippetValidationException(id, result);
    return code;
  }
}

/// Thrown by [ReviewSnippets.postableSnippet] when the rendered snippet
/// fails its validation gate. Carries the full result for the review-bot
/// log — the template must be fixed before anything is posted.
final class SnippetValidationException implements Exception {
  SnippetValidationException(this.templateId, this.result);

  final String templateId;
  final SnippetValidationResult result;

  @override
  String toString() =>
      'SnippetValidationException: template "$templateId" failed the '
      'snippet validation gate — ${result.render}';
}
