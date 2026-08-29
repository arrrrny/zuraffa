/// Shared DROP CARD helper for GYM exercises.
///
/// A DROP CARD is a structured mis-fire report emitted when an
/// exercise encounters an unexpected outcome (not a clean failure).
/// The format is fixed:
///
/// ```text
/// # DROP CARD — <exercise-id>
///
/// **Did**: <one-line summary of what the exercise attempted>
/// **Expected**: <the expected outcome>
/// **Happened**: <the actual outcome>
/// **Where**: <file:line or stage identifier>
///
/// ## Detail
/// <optional multi-line context>
/// ```
///
/// All four fields (Did / Expected / Happened / Where) are REQUIRED —
/// omitting any of them throws an [ArgumentError] at emission time
/// (FR-006). The DROP CARD is plain-text Markdown so it renders in
/// any viewer and diffs cleanly in version control.
///
/// See `specs/022-gym-real-exercises/spec.md` for the spec and
/// `specs/022-gym-real-exercises/plan.md` §D2 for the design.
library;

import 'dart:io';

/// A structured mis-fire report emitted by a GYM exercise.
class DropCard {
  /// The exercise id (e.g. `extend-zfa-cli`).
  final String exerciseId;

  /// One-line summary of what the exercise attempted.
  final String did;

  /// The expected outcome.
  final String expected;

  /// The actual outcome.
  final String happened;

  /// Stage identifier — file:line, spawn attempt, assertion name, etc.
  final String where;

  /// Optional multi-line context (call stack, stdout dump, etc.).
  final String? detail;

  DropCard({
    required this.exerciseId,
    required this.did,
    required this.expected,
    required this.happened,
    required this.where,
    this.detail,
  }) {
    if (exerciseId.isEmpty) {
      throw ArgumentError('DropCard.exerciseId must not be empty.');
    }
    if (did.isEmpty) {
      throw ArgumentError('DropCard.did must not be empty.');
    }
    if (expected.isEmpty) {
      throw ArgumentError('DropCard.expected must not be empty.');
    }
    if (happened.isEmpty) {
      throw ArgumentError('DropCard.happened must not be empty.');
    }
    if (where.isEmpty) {
      throw ArgumentError('DropCard.where must not be empty.');
    }
  }

  /// Renders the DROP CARD as plain-text Markdown.
  String emit() {
    final buf = StringBuffer()
      ..writeln('# DROP CARD — $exerciseId')
      ..writeln()
      ..writeln('**Did**: $did')
      ..writeln('**Expected**: $expected')
      ..writeln('**Happened**: $happened')
      ..writeln('**Where**: $where')
      ..writeln();
    if (detail != null && detail!.isNotEmpty) {
      buf.writeln('## Detail');
      buf.writeln();
      buf.writeln(detail);
    }
    return buf.toString();
  }

  /// Writes the DROP CARD to [file] (creating parent directories
  /// if needed). Returns the rendered string for convenience
  /// (callers typically also print it to stderr).
  String writeTo(File file) {
    final rendered = emit();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(rendered);
    return rendered;
  }

  /// Convenience: writes the DROP CARD to `<sandbox>/DROP_CARD.md`
  /// AND prints it to [stderr]. Used by every exercise's mis-fire
  /// path so the operator sees the card inline AND has a persisted
  /// artifact for post-mortem.
  ///
  /// [sandboxDir] is the exercise's sandbox root (typically
  /// `.gym/.sandbox/<exercise-id>/`).
  void emitAndPersist(String sandboxDir) {
    final rendered = writeTo(File('$sandboxDir/DROP_CARD.md'));
    stderr.writeln(rendered);
  }
}
